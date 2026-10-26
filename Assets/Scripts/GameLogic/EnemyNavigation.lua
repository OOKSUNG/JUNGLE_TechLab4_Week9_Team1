local MapModule = require("Map")
local EnemyNavigation = {}
EnemyNavigation.__index = EnemyNavigation

local Directions = { { X = 0, Y = -1 }, { X = 1, Y = 0 }, { X = 0, Y = 1 }, { X = -1, Y = 0 } }

local function PositionKey(Floor, X, Y)
    return Floor .. ":" .. X .. ":" .. Y
end

local function IsAreaClear(Navigation, Floor, WorldX, WorldY, ExtentX, ExtentY, Radius)
    local Map = Navigation.mMap
    local X = WorldY - Map.Origin.Y
    local Y = Map.Origin.X - WorldX
    local CellSize = Map.CellSize
    local HalfCell = CellSize * 0.5
    local MinimumX = math.floor((X - ExtentY) / CellSize + 0.5) + 1
    local MaximumX = math.floor((X + ExtentY) / CellSize + 0.5) + 1
    local MinimumY = math.floor((Y - ExtentX) / CellSize + 0.5) + 1
    local MaximumY = math.floor((Y + ExtentX) / CellSize + 0.5) + 1
    for Row = MinimumY, MaximumY do
        for Column = MinimumX, MaximumX do
            if not Map:IsWalkableAt(Floor, Column, Row) then
                if Radius == nil then
                    return false
                end
                local DistanceX = math.max(math.abs(X - (Column - 1) * CellSize) - HalfCell, 0.0)
                local DistanceY = math.max(math.abs(Y - (Row - 1) * CellSize) - HalfCell, 0.0)
                if DistanceX * DistanceX + DistanceY * DistanceY <= Radius * Radius then
                    return false
                end
            end
        end
    end
    return true
end

function EnemyNavigation.New(Map, Extent, Margin)
    local FloorVersions = {}
    for Floor, Data in pairs(Map.Floors) do
        FloorVersions[Floor] = Data
    end
    local HalfLength = Extent.X + Margin
    local HalfWidth = Extent.Y + Margin
    return setmetatable({ mMap = Map, mHalfLength = HalfLength, mHalfWidth = HalfWidth, mTurnRadius = math.sqrt(HalfLength * HalfLength + HalfWidth * HalfWidth), mSpacing = Map.CellSize * 0.5, mFloorVersions = FloorVersions, mClearance = {}, mTurns = {} }, EnemyNavigation)
end

function EnemyNavigation.IsCurrent(Navigation, Map)
    if Navigation.mMap ~= Map then
        return false
    end
    for Floor, Data in pairs(Map.Floors) do
        if Navigation.mFloorVersions[Floor] ~= Data then
            return false
        end
    end
    for Floor, Data in pairs(Navigation.mFloorVersions) do
        if Map.Floors[Floor] ~= Data then
            return false
        end
    end
    return true
end

function EnemyNavigation.ToWorld(Navigation, Floor, X, Y)
    local Map = Navigation.mMap
    return FVector.new(Map.Origin.X - Y * Navigation.mSpacing, Map.Origin.Y + X * Navigation.mSpacing, Map.Origin.Z + (Floor - 1) * Map.FloorHeight)
end

function EnemyNavigation.IsNodeClear(Navigation, Floor, X, Y, Heading)
    local Key = PositionKey(Floor, X, Y) .. ":" .. Heading % 2
    local Clear = Navigation.mClearance[Key]
    if Clear == nil then
        local Location = Navigation:ToWorld(Floor, X, Y)
        local ExtentX = Heading % 2 == 0 and Navigation.mHalfLength or Navigation.mHalfWidth
        local ExtentY = Heading % 2 == 0 and Navigation.mHalfWidth or Navigation.mHalfLength
        Clear = IsAreaClear(Navigation, Floor, Location.X, Location.Y, ExtentX, ExtentY)
        Navigation.mClearance[Key] = Clear
    end
    return Clear
end

function EnemyNavigation.CanTurn(Navigation, Location, Floor)
    local Radius = Navigation.mTurnRadius
    return IsAreaClear(Navigation, Floor, Location.X, Location.Y, Radius, Radius, Radius)
end

function EnemyNavigation.CanTurnAtNode(Navigation, Floor, X, Y)
    local Key = PositionKey(Floor, X, Y)
    local Clear = Navigation.mTurns[Key]
    if Clear == nil then
        Clear = Navigation:CanTurn(Navigation:ToWorld(Floor, X, Y), Floor)
        Navigation.mTurns[Key] = Clear
    end
    return Clear
end

function EnemyNavigation.CanMove(Navigation, From, To, Floor, Heading)
    local ExtentX = Heading % 2 == 0 and Navigation.mHalfLength or Navigation.mHalfWidth
    local ExtentY = Heading % 2 == 0 and Navigation.mHalfWidth or Navigation.mHalfLength
    return IsAreaClear(Navigation, Floor, (From.X + To.X) * 0.5, (From.Y + To.Y) * 0.5, ExtentX + math.abs(To.X - From.X) * 0.5, ExtentY + math.abs(To.Y - From.Y) * 0.5)
end

local function FindStart(Navigation, Location, Yaw, ChangeDirection)
    local Map = Navigation.mMap
    local Floor = Map:WorldToCell(Location).Floor
    local FloorData = Map.Floors[Floor]
    if FloorData == nil then
        return nil
    end
    local Heading = math.floor(Yaw / 90.0 + 0.5) % 4
    local Angle = (Heading * 90.0 - Yaw + 180.0) % 360.0 - 180.0
    if math.abs(Angle) > 0.01 and not Navigation:CanTurn(Location, Floor) then
        return nil
    end

    local GridX = math.floor((Location.Y - Map.Origin.Y) / Navigation.mSpacing + 0.5)
    local GridY = math.floor((Map.Origin.X - Location.X) / Navigation.mSpacing + 0.5)
    local Start = nil
    local BestDistance = math.huge
    local ForwardX = math.cos(math.rad(Heading * 90.0))
    local ForwardY = math.sin(math.rad(Heading * 90.0))
    for Y = GridY - 1, GridY + 1 do
        for X = GridX - 1, GridX + 1 do
            local Position = Navigation:ToWorld(Floor, X, Y)
            local Distance = (Position.X - Location.X) ^ 2 + (Position.Y - Location.Y) ^ 2
            local ForwardDistance = (Position.X - Location.X) * ForwardX + (Position.Y - Location.Y) * ForwardY
            if Distance < BestDistance and (not ChangeDirection or ForwardDistance >= -0.001) and Navigation:IsNodeClear(Floor, X, Y, Heading) and Navigation:CanMove(Location, Position, Floor, Heading) then
                Start = { Floor = Floor, X = X, Y = Y, Heading = Heading }
                BestDistance = Distance
            end
        end
    end
    return Start
end

local function ToSearchCell(X, Y, Heading)
    return { Floor = Heading + 1, X = X * 2 + 1, Y = Y * 2 + 1 }
end

local function IsSearchNodeClear(SearchMap, Layer, Column, Row)
    if Layer == 5 then
        return Column == SearchMap.mGoal.X and Row == SearchMap.mGoal.Y
    end
    if Layer < 1 or Layer > 4 or Column % 2 ~= 1 or Row % 2 ~= 1 then
        return false
    end
    local Navigation = SearchMap.mNavigation
    local Start = SearchMap.mStart
    local FloorData = Navigation.mMap.Floors[Start.Floor]
    local X = (Column - 1) * 0.5
    local Y = (Row - 1) * 0.5
    local Heading = Layer - 1
    if X < 0 or X > (FloorData.Width - 1) * 2 or Y < 0 or Y > (FloorData.Height - 1) * 2 or not Navigation:IsNodeClear(Start.Floor, X, Y, Heading) then
        return false
    end

    local Cell = ToSearchCell(X, Y, Heading)
    local Position = Navigation:ToWorld(Start.Floor, X, Y)
    if SearchMap.mTargetLocation ~= nil then
        local Distance = (Position.X - SearchMap.mTargetLocation.X) ^ 2 + (Position.Y - SearchMap.mTargetLocation.Y) ^ 2
        if Distance < SearchMap.mClosestDistance then
            SearchMap.mClosestCell = Cell
            SearchMap.mClosestDistance = Distance
        end
    end

    local Key = PositionKey(Layer, Column, Row)
    if not SearchMap.mLinked[Key] then
        SearchMap.mLinked[Key] = true
        local Direction = Directions[Layer]
        local Forward = Navigation:ToWorld(Start.Floor, X + Direction.X, Y + Direction.Y)
        if not (SearchMap.mChangeDirection and X == Start.X and Y == Start.Y and Heading == Start.Heading) and Navigation:CanMove(Position, Forward, Start.Floor, Heading) then
            SearchMap:AddLink(Cell, ToSearchCell(X + Direction.X, Y + Direction.Y, Heading), Navigation.mSpacing, true)
        end
        if Navigation:CanTurnAtNode(Start.Floor, X, Y) then
            SearchMap:AddLink(Cell, ToSearchCell(X, Y, (Heading + 1) % 4), Navigation.mSpacing, true)
            SearchMap:AddLink(Cell, ToSearchCell(X, Y, (Heading + 3) % 4), Navigation.mSpacing, true)
        else
            local Backward = Navigation:ToWorld(Start.Floor, X - Direction.X, Y - Direction.Y)
            if Navigation:CanMove(Position, Backward, Start.Floor, Heading) then
                SearchMap:AddLink(Cell, ToSearchCell(X - Direction.X, Y - Direction.Y, Heading), Navigation.mSpacing, true)
            end
        end
        if Column == SearchMap.mGoal.X and Row == SearchMap.mGoal.Y then
            SearchMap:AddLink(Cell, SearchMap.mGoal, 0.0, true)
        end
    end
    return true
end

local function FindRoute(Navigation, Start, X, Y, ChangeDirection, TargetLocation)
    local FloorData = Navigation.mMap.Floors[Start.Floor]
    X = math.max(0, math.min((FloorData.Width - 1) * 2, X))
    Y = math.max(0, math.min((FloorData.Height - 1) * 2, Y))
    local SearchMap = MapModule.New({ CellSize = Navigation.mSpacing * 0.5 })
    SearchMap.mNavigation = Navigation
    SearchMap.mStart = Start
    SearchMap.mGoal = { Floor = 5, X = X * 2 + 1, Y = Y * 2 + 1 }
    SearchMap.mChangeDirection = ChangeDirection
    SearchMap.mTargetLocation = TargetLocation
    SearchMap.mClosestCell = nil
    SearchMap.mClosestDistance = math.huge
    SearchMap.mLinked = {}
    SearchMap.IsWalkableAt = IsSearchNodeClear
    local StartCell = ToSearchCell(Start.X, Start.Y, Start.Heading)
    SearchMap:IsWalkable(StartCell)
    local Options = { bAllowDiagonal = false, MaxNodes = (FloorData.Width * 2 - 1) * (FloorData.Height * 2 - 1) * 4 + 1 }
    local Cells, Reason = SearchMap:FindPath(StartCell, SearchMap.mGoal, Options)
    if Cells == nil and Reason == "Unreachable" and TargetLocation ~= nil and SearchMap.mClosestCell ~= nil then
        Cells = SearchMap:FindPath(StartCell, SearchMap.mClosestCell, Options)
    end
    if Cells == nil then
        return nil
    end

    local Path = {}
    for _, Cell in ipairs(Cells) do
        if Cell.Floor <= 4 then
            local Point = { Location = Navigation:ToWorld(Start.Floor, (Cell.X - 1) * 0.5, (Cell.Y - 1) * 0.5), Floor = Start.Floor, Heading = Cell.Floor - 1 }
            local Count = #Path
            if Count >= 2 and Path[Count].Heading == Point.Heading and Path[Count - 1].Heading == Point.Heading then
                Path[Count] = Point
            else
                Path[#Path + 1] = Point
            end
        end
    end
    return Path
end

local function TrimPath(Path, Location)
    if Path == nil then
        return nil
    end
    while #Path > 1 and math.abs(Path[1].Location.X - Location.X) <= 0.001 and math.abs(Path[1].Location.Y - Location.Y) <= 0.001 and Path[1].Location.X == Path[2].Location.X and Path[1].Location.Y == Path[2].Location.Y do
        table.remove(Path, 1)
    end
    return Path
end

function EnemyNavigation.FindPatrolPath(Navigation, Location, Yaw, MinimumDistance, ChangeDirection)
    local Start = FindStart(Navigation, Location, Yaw, ChangeDirection)
    if Start == nil then
        return nil
    end
    local FloorData = Navigation.mMap.Floors[Start.Floor]
    local Range = math.ceil(math.max(MinimumDistance, Navigation.mMap.CellSize) * 2.0 / Navigation.mSpacing) + 4
    local Direction = Directions[Start.Heading + 1]
    local Goals = {}
    local NearbyGoals = {}
    local SideGoals = {}
    local NearbySideGoals = {}
    for Y = math.max(0, Start.Y - Range), math.min((FloorData.Height - 1) * 2, Start.Y + Range) do
        for X = math.max(0, Start.X - Range), math.min((FloorData.Width - 1) * 2, Start.X + Range) do
            local Distance = ((X - Start.X) ^ 2 + (Y - Start.Y) ^ 2) * Navigation.mSpacing * Navigation.mSpacing
            if Distance >= Navigation.mMap.CellSize * Navigation.mMap.CellSize and Navigation:CanTurnAtNode(Start.Floor, X, Y) then
                local Goal = { X = X, Y = Y }
                local Sideways = math.abs((X - Start.X) * Direction.Y - (Y - Start.Y) * Direction.X) > math.abs((X - Start.X) * Direction.X + (Y - Start.Y) * Direction.Y)
                NearbyGoals[#NearbyGoals + 1] = Goal
                if Sideways then
                    NearbySideGoals[#NearbySideGoals + 1] = Goal
                end
                if Distance >= MinimumDistance * MinimumDistance then
                    Goals[#Goals + 1] = Goal
                    if Sideways then
                        SideGoals[#SideGoals + 1] = Goal
                    end
                end
            end
        end
    end
    local Candidates = { ChangeDirection and SideGoals or Goals, ChangeDirection and NearbySideGoals or NearbyGoals, Goals, NearbyGoals }
    for _, List in ipairs(Candidates) do
        for Attempt = 1, math.min(#List, 8) do
            local Index = math.random(1, #List)
            local Goal = List[Index]
            List[Index] = List[#List]
            List[#List] = nil
            local Path = FindRoute(Navigation, Start, Goal.X, Goal.Y, ChangeDirection, nil)
            if Path ~= nil then
                return TrimPath(Path, Location)
            end
        end
    end
    return nil
end

function EnemyNavigation.FindChasePath(Navigation, Location, Yaw, TargetLocation)
    local Start = FindStart(Navigation, Location, Yaw, false)
    if Start == nil or Navigation.mMap:WorldToCell(TargetLocation).Floor ~= Start.Floor then
        return nil
    end
    local X = math.floor((TargetLocation.Y - Navigation.mMap.Origin.Y) / Navigation.mSpacing + 0.5)
    local Y = math.floor((Navigation.mMap.Origin.X - TargetLocation.X) / Navigation.mSpacing + 0.5)
    return TrimPath(FindRoute(Navigation, Start, X, Y, false, TargetLocation), Location)
end

return EnemyNavigation
