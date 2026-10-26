local Common = require("EnemyStates.Common")
local GameManager = require("GameManager")
local EnemyNavigation = require("EnemyNavigation")
local Chase = {}

local WaypointTolerance = 0.001
local AngleTolerance = 0.01

local function BuildPath(Context, Map, TargetLocation)
    local Data = Context.mData
    Data.mChaseMap = Map
    Data.mChasePath = nil
    Data.mChasePathIndex = 1
    Data.mChaseReplanElapsed = 0.0
    Data.mChaseTurning = false
    Data.mChaseTargetLocation = TargetLocation and FVector.new(TargetLocation.X, TargetLocation.Y, TargetLocation.Z) or nil
    if Map == nil or TargetLocation == nil then
        return
    end

    local Navigation = Data.mChaseNavigation or Data.mPatrolNavigation
    if Navigation == nil or not Navigation:IsCurrent(Map) then
        Navigation = EnemyNavigation.New(Map, Data.mPatrolExtent or FVector.new(0.0, 0.0, 0.0), Data.mPatrolWallMargin or 0.0)
    end
    Data.mChaseNavigation = Navigation
    local Location = Context.mOwner:GetActorLocation()
    Data.mChasePath = Navigation:FindChasePath(Location, Context.mOwner:GetActorRotation().Yaw, TargetLocation)
    Data.mChaseHeightOffset = Location.Z - Map:CellToWorld(Map:WorldToCell(Location)).Z
end

local function MoveOwner(Context, Delta, Rotation)
    if not Context.mOwner:Move(Delta, Rotation) then
        error("[EnemyFSM] Chase requires an actor with a root component")
    end
    return not Context.mData.mChaseInterrupted and Context.mMachine:IsRunning()
end

function Chase.Enter(Context, PreviousState)
    Context.mData.mChaseInterrupted = false
    BuildPath(Context, GameManager.GetMap(), GameManager.GetPlayerLocation())
    Common.ReportState(Context, PreviousState, "Chase")
end

function Chase.Tick(Context, DeltaTime)
    local TargetLocation = GameManager.GetPlayerLocation()
    if not GameManager.IsLightOn() or TargetLocation == nil then
        Context.mMachine:RequestState("Patrol")
        return
    end

    local Data = Context.mData
    local Owner = Context.mOwner
    local Map = GameManager.GetMap()
    local PreviousTarget = Data.mChaseTargetLocation
    local TargetMoved = PreviousTarget == nil or PreviousTarget.X ~= TargetLocation.X or PreviousTarget.Y ~= TargetLocation.Y or PreviousTarget.Z ~= TargetLocation.Z
    Data.mChaseReplanElapsed = Data.mChaseReplanElapsed + DeltaTime
    if Data.mChaseMap ~= Map or (Map ~= nil and (Data.mChaseNavigation == nil or not Data.mChaseNavigation:IsCurrent(Map))) or ((TargetMoved or Data.mChasePath == nil) and Data.mChaseReplanElapsed >= (Data.mChaseReplanInterval or 0.5) and not Data.mChaseTurning) then
        BuildPath(Context, Map, TargetLocation)
    end
    if Map == nil or Data.mChasePath == nil then
        return
    end

    local Navigation = Data.mChaseNavigation
    local RemainingTime = DeltaTime
    local Speed = Data.mChaseSpeed or 3.0
    local TurnSpeed = Data.mPatrolTurnSpeed or 360.0
    while Data.mChasePathIndex <= #Data.mChasePath do
        local Point = Data.mChasePath[Data.mChasePathIndex]
        local Target = Point.Location
        local Location = Owner:GetActorLocation()
        local Rotation = Owner:GetActorRotation()
        local TargetYaw = Point.Heading * 90.0
        local Angle = (TargetYaw - Rotation.Yaw + 180.0) % 360.0 - 180.0
        if math.abs(Angle) > AngleTolerance then
            if RemainingTime <= 0.0 or TurnSpeed <= 0.0 then
                return
            end
            if not Navigation:CanTurn(Location, Point.Floor) then
                Data.mChasePath = nil
                Data.mChaseTurning = false
                return
            end

            local Turn = math.min(math.abs(Angle), TurnSpeed * RemainingTime)
            Data.mChaseTurning = true
            local NewYaw = Rotation.Yaw + (Angle < 0.0 and -Turn or Turn)
            if not MoveOwner(Context, FVector.new(0.0, 0.0, 0.0), FRotator.new(Rotation.Pitch, NewYaw, Rotation.Roll)) then
                return
            end
            RemainingTime = RemainingTime - Turn / TurnSpeed
        else
            Data.mChaseTurning = false
            local DeltaX = Target.X - Location.X
            local DeltaY = Target.Y - Location.Y
            local DeltaZ = Target.Z + Data.mChaseHeightOffset - Location.Z
            local Distance = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ)
            if Distance <= WaypointTolerance then
                Data.mChasePathIndex = Data.mChasePathIndex + 1
            elseif RemainingTime <= 0.0 or Speed <= 0.0 then
                return
            else
                local Step = math.min(Distance, Speed * RemainingTime)
                local Scale = Step / Distance
                local Destination = FVector.new(Location.X + DeltaX * Scale, Location.Y + DeltaY * Scale, Location.Z + DeltaZ * Scale)
                if not Navigation:CanMove(Location, Destination, Point.Floor, Point.Heading) then
                    Data.mChasePath = nil
                    return
                end
                if not MoveOwner(Context, FVector.new(DeltaX * Scale, DeltaY * Scale, DeltaZ * Scale), FRotator.new(Rotation.Pitch, TargetYaw, Rotation.Roll)) then
                    return
                end

                local NewLocation = Owner:GetActorLocation()
                local NewDistance = math.sqrt((Target.X - NewLocation.X) ^ 2 + (Target.Y - NewLocation.Y) ^ 2 + (Target.Z + Data.mChaseHeightOffset - NewLocation.Z) ^ 2)
                if Distance - NewDistance < Step - WaypointTolerance then
                    Data.mChasePath = nil
                    return
                end
                RemainingTime = RemainingTime - Step / Speed
            end
        end
    end
end

function Chase.Exit(Context, NextState)
    Context.mData.mPatrolPath = nil
    Context.mData.mChasePath = nil
end

function Chase.HandleEvent(Context, EventName, ...)
    Common.HandleInterruption(Context, EventName)
end

return Chase
