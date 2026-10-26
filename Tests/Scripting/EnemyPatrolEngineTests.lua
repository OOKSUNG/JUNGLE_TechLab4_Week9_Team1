local FSM = require("FSM")
local States = require("EnemyStates")
local Map = require("Map")
local MapData = require("MapData")
local GameManager = require("GameManager")
local CurrentMap = Map.New(MapData)
for Floor, Text in pairs(MapData.Floors) do
    CurrentMap:LoadFloor(Floor, Text)
end
GameManager.SetMap(CurrentMap)

local Extent = PatrolTestOwner:GetNavigationExtent()
assert(math.abs(Extent.X - 0.9414) < 0.001 and math.abs(Extent.Y - 0.6947) < 0.001, "Native mesh extent does not include the mesh transform")
PatrolTestOwner:SetActorRotation(FRotator.new(0.0, 123.0, 0.0))
PatrolTestOwner:SetActorScale3D(FVector.new(1.25, 0.75, 1.0))
local ScaledExtent = PatrolTestOwner:GetNavigationExtent()
assert(math.abs(ScaledExtent.X - PatrolExpectedScaledExtent.X) < 0.001 and math.abs(ScaledExtent.Y - PatrolExpectedScaledExtent.Y) < 0.001, "Native navigation extent does not match transformed mesh vertices")
PatrolTestOwner:SetActorRotation(FRotator.new(0.0, 0.0, 0.0))
PatrolTestOwner:SetActorScale3D(FVector.new(1.0, 1.0, 1.0))
local Data = { mPatrolSpeed = 2.0, mPatrolTurnSpeed = 360.0, mPatrolExtent = Extent, mPatrolWallMargin = 0.04, mIdleDuration = 1.0, mStunDuration = 1.5, mResumeState = "Idle" }
local Machine = FSM.New(PatrolTestOwner, States, Data)
math.randomseed(37)
Machine:Start("Idle")
local TotalDistance = 0.0
local Times = { 1.0 / 240.0, 1.0 / 60.0, 0.075, 0.21 }
local Rooms = {}
for Frame = 1, 3000 do
    local Previous = PatrolTestOwner:GetActorLocation()
    local PreviousYaw = PatrolTestOwner:GetActorRotation().Yaw
    local DeltaTime = Times[Frame % #Times + 1]
    if Frame % 397 == 0 then
        Machine:HandleEvent("Stun")
    end
    Machine:Tick(DeltaTime)
    local Location = PatrolTestOwner:GetActorLocation()
    local Yaw = PatrolTestOwner:GetActorRotation().Yaw
    local Distance = math.sqrt((Location.X - Previous.X) ^ 2 + (Location.Y - Previous.Y) ^ 2)
    local Turn = math.abs((Yaw - PreviousYaw + 180.0) % 360.0 - 180.0)
    assert(Distance <= Data.mPatrolSpeed * DeltaTime + 0.002, "Native patrol exceeded its movement budget")
    assert(Turn <= Data.mPatrolTurnSpeed * DeltaTime + 0.002, "Native patrol snapped its direction")
    TotalDistance = TotalDistance + Distance
    local Cell = CurrentMap:WorldToCell(Location)
    Rooms[math.floor((Cell.X - 1) / 16)] = true
    local Cosine = math.cos(math.rad(Yaw))
    local Sine = math.sin(math.rad(Yaw))
    for Forward = -10, 10 do
        for Right = -10, 10 do
            local X = Extent.X * Forward / 10.0
            local Y = Extent.Y * Right / 10.0
            local Point = FVector.new(Location.X + X * Cosine - Y * Sine, Location.Y + X * Sine + Y * Cosine, Location.Z)
            assert(CurrentMap:IsWalkable(CurrentMap:WorldToCell(Point)), "Native monster body overlapped a wall")
        end
    end
end

local RoomCount = 0
for Room in pairs(Rooms) do
    RoomCount = RoomCount + 1
end
assert(TotalDistance > 200.0 and RoomCount >= 2, "Native patrol did not progress through map passages")
PatrolTestDistance = TotalDistance
PatrolTestRoomCount = RoomCount
Log("[EnemyPatrolEngineTests] PASS", "distance", TotalDistance, "rooms", RoomCount)
Machine:Stop()
GameManager.Reset()
