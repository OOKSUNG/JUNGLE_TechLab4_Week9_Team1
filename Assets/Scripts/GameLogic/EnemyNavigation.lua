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

local function FindPath(Navigation, Location, Yaw, MinimumDistance, ChangeDirection, TargetLocation)
    local Map = Navigation.mMap
    local Floor = Map:WorldToCell(Location).Floor
    local FloorData = Map.Floors[Floor]
    if FloorData == nil then
        return nil
    end
    if TargetLocation ~= nil and Map:WorldToCell(TargetLocation).Floor ~= Floor then
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
                Start = { X = X, Y = Y, Heading = Heading, Depth = 0 }
                BestDistance = Distance
            end
        end
    end
    if Start == nil then
        return nil
    end

    local Nodes = { Start }
    local Visited = { [PositionKey(Floor, Start.X, Start.Y) .. ":" .. Heading] = true }
    local Goals = {}
    local NearbyGoals = {}
    local SideGoals = {}
    local NearbySideGoals = {}
    local MaximumDepth = math.ceil(MinimumDistance * 2.0 / Navigation.mSpacing) + 4
    local ChaseGoal = nil
    local ChaseDistance = math.huge
    local Index = 1
    while Index <= #Nodes do
        local Node = Nodes[Index]
        if TargetLocation ~= nil then
            local Position = Navigation:ToWorld(Floor, Node.X, Node.Y)
            local Distance = (Position.X - TargetLocation.X) ^ 2 + (Position.Y - TargetLocation.Y) ^ 2
            if Distance < ChaseDistance then
                ChaseGoal = Index
                ChaseDistance = Distance
            end
            if ChaseDistance <= Navigation.mSpacing * Navigation.mSpacing * 0.5 + 0.000001 then
                break
            end
        elseif Node.Depth > MaximumDepth and #NearbyGoals > 0 then
            break
        end
        local CanTurn = Navigation:CanTurnAtNode(Floor, Node.X, Node.Y)
        local Distance = ((Node.X - Start.X) ^ 2 + (Node.Y - Start.Y) ^ 2) * Navigation.mSpacing * Navigation.mSpacing
        if TargetLocation == nil and Node.Moved and CanTurn and Distance >= Map.CellSize * Map.CellSize and (not ChangeDirection or Node.FirstHeading ~= Heading) then
            NearbyGoals[#NearbyGoals + 1] = Index
            local Sideways = Node.FirstHeading % 2 ~= Heading % 2
            if Sideways then
                NearbySideGoals[#NearbySideGoals + 1] = Index
            end
            if Distance >= MinimumDistance * MinimumDistance then
                Goals[#Goals + 1] = Index
                if Sideways then
                    SideGoals[#SideGoals + 1] = Index
                end
            end
        end

        local Direction = Directions[Node.Heading + 1]
        local NextNodes = { { X = Node.X + Direction.X, Y = Node.Y + Direction.Y, Heading = Node.Heading, Parent = Index, Depth = Node.Depth + 1, FirstHeading = Node.FirstHeading or Node.Heading, Moved = true } }
        if CanTurn then
            NextNodes[#NextNodes + 1] = { X = Node.X, Y = Node.Y, Heading = (Node.Heading + 1) % 4, Parent = Index, Depth = Node.Depth + 1, FirstHeading = Node.FirstHeading }
            NextNodes[#NextNodes + 1] = { X = Node.X, Y = Node.Y, Heading = (Node.Heading + 3) % 4, Parent = Index, Depth = Node.Depth + 1, FirstHeading = Node.FirstHeading }
        else
            NextNodes[#NextNodes + 1] = { X = Node.X - Direction.X, Y = Node.Y - Direction.Y, Heading = Node.Heading, Parent = Index, Depth = Node.Depth + 1, FirstHeading = Node.FirstHeading or (Node.Heading + 2) % 4, Moved = true }
        end
        for _, Next in ipairs(NextNodes) do
            local Key = PositionKey(Floor, Next.X, Next.Y) .. ":" .. Next.Heading
            if not Visited[Key] and Next.X >= 0 and Next.X <= (FloorData.Width - 1) * 2 and Next.Y >= 0 and Next.Y <= (FloorData.Height - 1) * 2 and Navigation:IsNodeClear(Floor, Next.X, Next.Y, Next.Heading) then
                Visited[Key] = true
                Nodes[#Nodes + 1] = Next
            end
        end
        Index = Index + 1
    end

    if ChangeDirection and #SideGoals > 0 then
        Goals = SideGoals
    elseif #Goals == 0 and ChangeDirection and #NearbySideGoals > 0 then
        Goals = NearbySideGoals
    elseif #Goals == 0 then
        Goals = NearbyGoals
    end
    if TargetLocation == nil and #Goals == 0 then
        return nil
    end

    local ReversePath = {}
    local GoalIndex = ChaseGoal or Goals[math.random(1, #Goals)]
    while GoalIndex ~= nil do
        local Node = Nodes[GoalIndex]
        ReversePath[#ReversePath + 1] = { Location = Navigation:ToWorld(Floor, Node.X, Node.Y), Floor = Floor, Heading = Node.Heading }
        GoalIndex = Node.Parent
    end

    local Path = {}
    for PathIndex = #ReversePath, 1, -1 do
        local Point = ReversePath[PathIndex]
        local Count = #Path
        if Count >= 2 and Path[Count].Heading == Point.Heading and Path[Count - 1].Heading == Point.Heading then
            Path[Count] = Point
        else
            Path[#Path + 1] = Point
        end
    end
    while #Path > 1 and math.abs(Path[1].Location.X - Location.X) <= 0.001 and math.abs(Path[1].Location.Y - Location.Y) <= 0.001 and Path[1].Location.X == Path[2].Location.X and Path[1].Location.Y == Path[2].Location.Y do
        table.remove(Path, 1)
    end
    return Path
end

function EnemyNavigation.FindPatrolPath(Navigation, Location, Yaw, MinimumDistance, ChangeDirection)
    return FindPath(Navigation, Location, Yaw, MinimumDistance, ChangeDirection, nil)
end

function EnemyNavigation.FindChasePath(Navigation, Location, Yaw, TargetLocation)
    return FindPath(Navigation, Location, Yaw, 0.0, false, TargetLocation)
end

return EnemyNavigation
