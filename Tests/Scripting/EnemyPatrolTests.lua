package.path = "Assets/Scripts/?.lua;Assets/Scripts/GameLogic/?.lua;" .. package.path

local FSM = require("FSM")
local States = require("EnemyStates")
local Map = require("Map")
local GameManager = require("GameManager")
local Ffi = require("ffi")
local Actor = {}
Actor.__index = Actor

FVector = {}
FRotator = {}
Key = { Space = "Space" }

function FVector.new(X, Y, Z)
    return { X = tonumber(Ffi.new("float", X)), Y = tonumber(Ffi.new("float", Y)), Z = tonumber(Ffi.new("float", Z)) }
end

function FRotator.new(Pitch, Yaw, Roll)
    return { Pitch = tonumber(Ffi.new("float", Pitch)), Yaw = tonumber(Ffi.new("float", Yaw)), Roll = tonumber(Ffi.new("float", Roll)) }
end

function Log(...)
end

function IsKeyPressed(KeyCode)
    return false
end

local function Near(Actual, Expected)
    assert(math.abs(Actual - Expected) <= 0.002, tostring(Actual) .. " ~= " .. tostring(Expected))
end

local function LastRandom(Minimum, Maximum)
    return Maximum
end

local function BuildMap(Text)
    local Result = Map.New({ Origin = { X = 10.0, Y = 20.0, Z = 3.0 }, CellSize = 1.0 })
    Result:LoadFloor(1, Text)
    return Result
end

local function AssertBodyClear(CurrentMap, Location, Yaw, Extent)
    local Radians = math.rad(Yaw)
    local Cosine = math.cos(Radians)
    local Sine = math.sin(Radians)
    local AbsoluteCosine = math.abs(Cosine)
    local AbsoluteSine = math.abs(Sine)
    local HalfCell = CurrentMap.CellSize * 0.5
    local WorldExtentX = AbsoluteCosine * Extent.X + AbsoluteSine * Extent.Y
    local WorldExtentY = AbsoluteSine * Extent.X + AbsoluteCosine * Extent.Y
    local Cell = CurrentMap:WorldToCell(Location)
    local Range = math.ceil((WorldExtentX + WorldExtentY) / CurrentMap.CellSize) + 1
    for Y = Cell.Y - Range, Cell.Y + Range do
        for X = Cell.X - Range, Cell.X + Range do
            if not CurrentMap:IsWalkableAt(Cell.Floor, X, Y) then
                local Wall = CurrentMap:CellToWorld({ Floor = Cell.Floor, X = X, Y = Y })
                local DeltaX = Wall.X - Location.X
                local DeltaY = Wall.Y - Location.Y
                local OverlapX = math.abs(DeltaX) < WorldExtentX + HalfCell - 0.0001
                local OverlapY = math.abs(DeltaY) < WorldExtentY + HalfCell - 0.0001
                local OverlapForward = math.abs(DeltaX * Cosine + DeltaY * Sine) < Extent.X + HalfCell * (AbsoluteCosine + AbsoluteSine) - 0.0001
                local OverlapRight = math.abs(-DeltaX * Sine + DeltaY * Cosine) < Extent.Y + HalfCell * (AbsoluteCosine + AbsoluteSine) - 0.0001
                assert(not (OverlapX and OverlapY and OverlapForward and OverlapRight), "Patrol body overlapped a wall")
            end
        end
    end
end

function Actor.New(CurrentMap, Cell)
    local Location = CurrentMap:CellToWorld(Cell)
    Location.Z = Location.Z + 1.25
    return setmetatable({ mMap = CurrentMap, mLocation = Location, mRotation = FRotator.new(0.0, 0.0, 0.0), mExtent = FVector.new(0.1, 0.1, 0.1), mDistance = 0.0, mTurned = 0.0, mMoves = {}, mBlocked = false, mCanMove = true }, Actor)
end

function Actor.GetNavigationExtent(Owner)
    return Owner.mExtent
end

function Actor.GetActorLocation(Owner)
    return FVector.new(Owner.mLocation.X, Owner.mLocation.Y, Owner.mLocation.Z)
end

function Actor.GetActorRotation(Owner)
    return Owner.mRotation
end

function Actor.GetName(Owner)
    return "EnemyPatrolTest"
end

function Actor.Move(Owner, Delta, Rotation)
    if not Owner.mCanMove then
        return false
    end
    if Owner.mBlocked then
        Owner.mRotation = Rotation
        return true
    end

    local Distance = math.sqrt(Delta.X * Delta.X + Delta.Y * Delta.Y + Delta.Z * Delta.Z)
    local Angle = (Rotation.Yaw - Owner.mRotation.Yaw + 180.0) % 360.0 - 180.0
    local Samples = math.max(1, math.ceil(Distance / 0.05), math.ceil(math.abs(Angle) / 2.0))
    for Index = 1, Samples do
        local Scale = Index / Samples
        local Sample = FVector.new(Owner.mLocation.X + Delta.X * Scale, Owner.mLocation.Y + Delta.Y * Scale, Owner.mLocation.Z + Delta.Z * Scale)
        assert(Owner.mMap:IsWalkable(Owner.mMap:WorldToCell(Sample)), "Patrol crossed a wall")
        AssertBodyClear(Owner.mMap, Sample, Owner.mRotation.Yaw + Angle * Scale, Owner.mExtent)
    end

    Owner.mDistance = Owner.mDistance + Distance
    Owner.mTurned = Owner.mTurned + math.abs(Angle)
    Owner.mMoves[#Owner.mMoves + 1] = Delta
    Owner.mLocation = FVector.new(Owner.mLocation.X + Delta.X, Owner.mLocation.Y + Delta.Y, Owner.mLocation.Z + Delta.Z)
    Owner.mRotation = Rotation
    if Owner.mAfterMove ~= nil then
        Owner.mAfterMove(Owner)
    end
    return true
end

local function NewMachine(Owner)
    local Data = { mPatrolSpeed = 2.0, mPatrolTurnSpeed = math.huge, mPatrolExtent = Owner:GetNavigationExtent(), mPatrolWallMargin = 0.02, mIdleDuration = 1.0, mStunDuration = 1.5, mResumeState = "Idle" }
    return FSM.New(Owner, States, Data), Data
end

local Corridor = "########\n#..#####\n##.#####\n##....##\n#####.##\n#####.##\n########"
local StartCell = { Floor = 1, X = 2, Y = 2 }
local OriginalRandom = math.random
math.random = LastRandom

local function TestCorridor()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(1.25)
    Near(Owner.mDistance, 2.5)
    Near(Owner.mLocation.X, 7.5)
    Near(Owner.mLocation.Y, 22.0)
    Near(Owner.mRotation.Yaw, 180.0)
    Machine:Tick(100.0)
    assert(Machine:GetCurrentState() == "Idle")
    Near(Owner.mDistance, 8.0)
    Near(Owner.mLocation.Z, 4.25)
    assert(Map.IsSameCell(CurrentMap:WorldToCell(Owner.mLocation), { Floor = 1, X = 6, Y = 6 }))
    Machine:Tick(0.5)
    assert(Machine:GetCurrentState() == "Idle")
    Machine:Tick(0.5)
    assert(Machine:GetCurrentState() == "Patrol")
    Machine:Tick(0.25)
    Near(Owner.mDistance, 8.5)
end

local function TestStunResume()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine, Data = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(0.25)
    local Path = Data.mPatrolPath
    local PathIndex = Data.mPatrolPathIndex
    Machine:HandleEvent("Stun")
    assert(Machine:GetCurrentState() == "Stunned")
    Machine:Tick(0.75)
    Near(Owner.mDistance, 0.5)
    Machine:Tick(0.75)
    assert(Machine:GetCurrentState() == "Patrol")
    assert(Data.mPatrolPath == Path and Data.mPatrolPathIndex == PathIndex)
    Machine:Tick(0.25)
    Near(Owner.mDistance, 1.0)
end

local function TestLateMap()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(nil)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(0.25)
    assert(Machine:GetCurrentState() == "Idle" and Owner.mDistance == 0.0)
    GameManager.SetMap(CurrentMap)
    Machine:Tick(1.0)
    Machine:Tick(0.5)
    Near(Owner.mDistance, 1.0)
    GameManager.SetMap(nil)
    Machine:Tick(0.5)
    assert(Machine:GetCurrentState() == "Idle")
    Near(Owner.mDistance, 1.0)
end

local function TestInvalidStart()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 1, Y = 1 })
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(1.0)
    assert(Machine:GetCurrentState() == "Idle" and Owner.mDistance == 0.0)
    CurrentMap = BuildMap("#####\n#.###\n#####")
    GameManager.SetMap(CurrentMap)
    Owner = Actor.New(CurrentMap, StartCell)
    Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(1.0)
    assert(Machine:GetCurrentState() == "Idle" and Owner.mDistance == 0.0)
end

local function TestDisconnectedMap()
    local CurrentMap = BuildMap("##########\n#..##....#\n##########")
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    for Index = 1, 100 do
        Machine:Tick(0.25)
        assert(CurrentMap:WorldToCell(Owner.mLocation).X <= 3)
    end
    assert(Owner.mDistance > 10.0)
end

local function TestMapReplacement()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine, Data = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(0.25)
    local OldPath = Data.mPatrolPath
    local Replacement = BuildMap("########\n#......#\n########")
    GameManager.SetMap(Replacement)
    Owner.mMap = Replacement
    Machine:Tick(0.25)
    assert(Data.mPatrolMap == Replacement and Data.mPatrolPath ~= OldPath)
    Near(Owner.mLocation.Z, 4.25)
    Machine:Tick(100.0)
    assert(Machine:GetCurrentState() == "Idle")
end

local function TestBlockedMovement()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    Owner.mBlocked = true
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(0.5)
    assert(Machine:GetCurrentState() == "Patrol")
    Machine:Tick(0.5)
    assert(Machine:GetCurrentState() == "Idle" and Owner.mDistance == 0.0)
    Owner.mBlocked = false
    Machine:Tick(1.0)
    Machine:Tick(0.25)
    Near(Owner.mDistance, 0.5)
end

local function TestInvalidatedPath()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(0.0)
    CurrentMap:LoadFloor(1, "########\n#.######\n########")
    Machine:Tick(1.0)
    assert(Machine:GetCurrentState() == "Idle" and Owner.mDistance == 0.0)
end

local function TestScriptLifecycle()
    GameManager.Reset()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local FirstOwner = Actor.New(CurrentMap, StartCell)
    local SecondOwner = Actor.New(CurrentMap, StartCell)
    local First = setmetatable({ self = FirstOwner }, { __index = _G })
    local Second = setmetatable({ self = SecondOwner }, { __index = _G })
    setfenv(assert(loadfile("Assets/Scripts/EnemyFSM.lua")), First)()
    setfenv(assert(loadfile("Assets/Scripts/EnemyFSM.lua")), Second)()
    First.BeginPlay()
    Second.BeginPlay()
    assert(#GameManager.GetEnemies() == 2)
    First.Tick(2.0)
    Second.Tick(2.0)
    Near(FirstOwner.mDistance, 0.0)
    Near(SecondOwner.mDistance, 0.0)
    GameManager.StartGame()
    First.Tick(1.0)
    Second.Tick(0.25)
    First.Tick(1.0)
    assert(FirstOwner.mDistance >= 1.0 and FirstOwner.mDistance <= 2.0)
    Near(SecondOwner.mDistance, 0.0)
    GameManager.GameOver("EnemyPatrolTest")
    local StoppedDistance = FirstOwner.mDistance
    First.Tick(5.0)
    Second.Tick(5.0)
    Near(FirstOwner.mDistance, StoppedDistance)
    Near(SecondOwner.mDistance, 0.0)
    First.OnReload()
    assert(#GameManager.GetEnemies() == 2)
    First.Tick(5.0)
    Near(FirstOwner.mDistance, StoppedDistance)
    First.EndPlay()
    Second.EndPlay()
    assert(#GameManager.GetEnemies() == 0)
end

local function TestScaledUpperFloor()
    local CurrentMap = Map.New({ Origin = { X = 13.0, Y = 29.0, Z = 5.0 }, CellSize = 2.5, FloorHeight = 6.0, bAllowDiagonal = true })
    CurrentMap:LoadFloor(2, Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 2, X = 2, Y = 2 })
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:Tick(1.25)
    Near(Owner.mDistance, 2.5)
    Machine:Tick(100.0)
    assert(Machine:GetCurrentState() == "Idle")
    Near(Owner.mDistance, 20.0)
    Near(Owner.mLocation.Z, 12.25)
    assert(CurrentMap:WorldToCell(Owner.mLocation).Floor == 2)
end

local function TestActualMap()
    local MapData = require("MapData")
    math.random = OriginalRandom
    for Seed = 1, 4 do
        math.randomseed(Seed)
        local CurrentMap = Map.New(MapData)
        for Floor, Text in pairs(MapData.Floors) do
            CurrentMap:LoadFloor(Floor, Text)
        end
        GameManager.SetMap(CurrentMap)
        local Spawn = FVector.new(-22.5, 4.5, 0.0)
        local Owner = Actor.New(CurrentMap, CurrentMap:WorldToCell(Spawn))
        Owner.mLocation = Spawn
        Owner.mExtent = FVector.new(0.9414, 0.6947, 1.893)
        local Machine, Data = NewMachine(Owner)
        Data.mPatrolTurnSpeed = 360.0
        Data.mPatrolWallMargin = 0.04
        Machine:Start("Idle")
        for Frame = 1, 3000 do
            if Frame % 251 == 0 then
                Machine:HandleEvent("Stun")
            end
            Machine:Tick(0.05)
        end
        assert(Owner.mDistance > 150.0, "Actual map patrol stopped progressing: " .. Seed .. ", " .. Owner.mDistance .. ", " .. Machine:GetCurrentState() .. ", " .. Owner.mLocation.X .. ", " .. Owner.mLocation.Y)
        Near(Owner.mLocation.Z, 0.0)
    end
    math.random = LastRandom
end

local function TestDoorwayClearance()
    local CurrentMap = BuildMap("##################\n#.....######.....#\n#.....######.....#\n#................#\n#................#\n#.....######.....#\n#.....######.....#\n##################")
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 4, Y = 4 })
    Owner.mLocation.X = Owner.mLocation.X - 0.5
    Owner.mExtent = FVector.new(0.9414, 0.6947, 1.893)
    Owner.mRotation.Yaw = 90.0
    local Machine, Data = NewMachine(Owner)
    Data.mPatrolTurnSpeed = 360.0
    Data.mPatrolReplanInterval = 0.0
    Machine:Start("Patrol")
    for Frame = 1, 1200 do
        Machine:Tick(0.05)
        if Machine:GetCurrentState() == "Idle" then
            break
        end
    end
    assert(Machine:GetCurrentState() == "Idle")
    assert(CurrentMap:WorldToCell(Owner.mLocation).X >= 13, "Patrol did not cross the two-cell doorway")
end

local function TestNarrowDoorway()
    local CurrentMap = BuildMap("##################\n#.....######.....#\n#.....######.....#\n#................#\n#.....######.....#\n#.....######.....#\n#.....######.....#\n##################")
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 4, Y = 4 })
    Owner.mExtent = FVector.new(0.9414, 0.6947, 1.893)
    Owner.mRotation.Yaw = 90.0
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    for Frame = 1, 1200 do
        Machine:Tick(0.05)
        assert(CurrentMap:WorldToCell(Owner.mLocation).X <= 6, "Patrol entered a passage narrower than its body")
    end
end

local function TestTurnRate()
    local CurrentMap = BuildMap("#########\n#.......#\n#.......#\n#.......#\n#.......#\n#.......#\n#.......#\n#.......#\n#########")
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 5, Y = 5 })
    Owner.mExtent = FVector.new(0.6, 0.4, 0.5)
    Owner.mRotation.Yaw = 179.95
    local Machine, Data = NewMachine(Owner)
    Data.mPatrolTurnSpeed = 360.0
    Machine:Start("Patrol")
    for Frame = 1, 600 do
        local PreviousTurned = Owner.mTurned
        local PreviousDistance = Owner.mDistance
        Machine:Tick(1.0 / 60.0)
        assert(Owner.mTurned - PreviousTurned <= 6.001, "Patrol snapped its facing direction")
        assert(Owner.mDistance - PreviousDistance <= 2.0 / 60.0 + 0.001)
    end
    assert(Owner.mDistance > 5.0)
end

local function InterruptMovement(Owner)
    if Owner.mDistance > 0.0 then
        Owner.mAfterMove = nil
        Owner.mMachine:HandleEvent("Stun")
    end
end

local function TestCollisionEvents()
    local CurrentMap = BuildMap(Corridor)
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, StartCell)
    local Machine = NewMachine(Owner)
    Machine:Start("Patrol")
    Machine:HandleEvent("OnHit", nil, {})
    Machine:HandleEvent("OnOverlap", nil)
    assert(Machine:GetCurrentState() == "Patrol", "Ordinary collisions stunned the patrol")
    Owner.mMachine = Machine
    Owner.mAfterMove = InterruptMovement
    Machine:Tick(100.0)
    assert(Machine:GetCurrentState() == "Stunned")
    assert(Owner.mDistance > 0.0 and Owner.mDistance < 8.0, "Patrol continued through waypoints after being stunned")
end

local function BuildOpenMap()
    local Rows = { string.rep("#", 40) }
    for Row = 2, 29 do
        Rows[#Rows + 1] = "#" .. string.rep(".", 38) .. "#"
    end
    Rows[#Rows + 1] = string.rep("#", 40)
    return BuildMap(table.concat(Rows, "\n"))
end

local function TestReplanBeforeWall()
    local CurrentMap = BuildOpenMap()
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 20, Y = 15 })
    Owner.mExtent = FVector.new(0.6, 0.4, 0.5)
    local Machine, Data = NewMachine(Owner)
    Data.mPatrolMinimumDistance = 8.0
    Data.mPatrolTurnSpeed = 180.0
    Data.mPatrolReplanInterval = 0.6
    Machine:Start("Patrol")
    local OriginalPath = Data.mPatrolPath
    local OriginalGoal = OriginalPath[#OriginalPath].Location
    local Replanned = false
    for Frame = 1, 240 do
        local Previous = Owner:GetActorLocation()
        local PreviousYaw = Owner.mRotation.Yaw
        Machine:Tick(1.0 / 60.0)
        if Data.mPatrolPath ~= OriginalPath then
            assert(Data.mPatrolPath ~= nil and Machine:GetCurrentState() == "Patrol")
            local DistanceToGoal = math.sqrt((OriginalGoal.X - Previous.X) ^ 2 + (OriginalGoal.Y - Previous.Y) ^ 2)
            assert(DistanceToGoal > 4.0, "Patrol waited until its destination to replan")
            local First = Data.mPatrolPath[1].Location
            local Forward = (First.X - Previous.X) * math.cos(math.rad(PreviousYaw)) + (First.Y - Previous.Y) * math.sin(math.rad(PreviousYaw))
            assert(Forward >= -0.001, "Replanning snapped the patrol back to a previous grid point")
            local Cell = CurrentMap:WorldToCell(Previous)
            assert(Cell.X > 4 and Cell.X < 36 and Cell.Y > 4 and Cell.Y < 26, "Patrol reached a wall before changing direction")
            Replanned = true
            break
        end
    end
    assert(Replanned, "Patrol did not replan during movement")
end

local function TestTurnCommitment()
    local CurrentMap = BuildOpenMap()
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 20, Y = 15 })
    Owner.mExtent = FVector.new(0.6, 0.4, 0.5)
    Owner.mRotation.Yaw = 45.0
    local Machine, Data = NewMachine(Owner)
    Data.mPatrolTurnSpeed = 90.0
    Data.mPatrolReplanInterval = 0.05
    Machine:Start("Patrol")
    local Path = Data.mPatrolPath
    local TargetYaw = Path[1].Heading * 90.0
    Machine:Tick(0.05)
    assert(Data.mPatrolTurning)
    Data.mPatrolReplanElapsed = 10.0
    local PreviousError = math.abs((TargetYaw - Owner.mRotation.Yaw + 180.0) % 360.0 - 180.0)
    for Frame = 1, 8 do
        Machine:Tick(0.05)
        assert(Data.mPatrolPath == Path, "Patrol replaced its direction while rotating")
        local Error = math.abs((TargetYaw - Owner.mRotation.Yaw + 180.0) % 360.0 - 180.0)
        assert(Error <= PreviousError + 0.001, "Patrol reversed its turn")
        PreviousError = Error
    end
end

local function TestBackOutBeforeTurning()
    local CurrentMap = BuildMap("########\n#......#\n#......#\n#......#\n#......#\n#......#\n#......#\n########")
    GameManager.SetMap(CurrentMap)
    local Owner = Actor.New(CurrentMap, { Floor = 1, X = 4, Y = 3 })
    Owner.mLocation.X = Owner.mLocation.X + 0.5
    Owner.mExtent = FVector.new(0.94, 0.69, 1.89)
    Owner.mRotation.Yaw = 0.0
    local Machine, Data = NewMachine(Owner)
    Data.mPatrolTurnSpeed = 180.0
    Machine:Start("Patrol")
    local InitialX = Owner.mLocation.X
    Machine:Tick(0.2)
    assert(Owner.mLocation.X < InitialX, "Patrol did not back away from a wall to obtain turning clearance")
    Near(Owner.mRotation.Yaw, 0.0)
    for Frame = 1, 100 do
        Machine:Tick(0.05)
    end
    assert(Owner.mTurned > 45.0 and Owner.mDistance > 2.0)
end

local Tests = { TestCorridor, TestStunResume, TestLateMap, TestInvalidStart, TestDisconnectedMap, TestMapReplacement, TestBlockedMovement, TestInvalidatedPath, TestScriptLifecycle, TestScaledUpperFloor, TestActualMap, TestDoorwayClearance, TestNarrowDoorway, TestTurnRate, TestCollisionEvents, TestReplanBeforeWall, TestTurnCommitment, TestBackOutBeforeTurning }
for Index, Test in ipairs(Tests) do
    Test()
    print("[EnemyPatrolTests] PASS", Index)
end

math.random = OriginalRandom
GameManager.Reset()
print("[EnemyPatrolTests] Passed", #Tests, "tests")
