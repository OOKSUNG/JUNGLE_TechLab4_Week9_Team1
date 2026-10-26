local Common = require("FSMExampleStates.Common")
local Patrol = {}

function Patrol.Enter(Context, PreviousState)
    local Data = Context.mData
    Data.mDestinationX = Data.mOrigin.X + Data.mDirection * Data.mPatrolDistance
    Common.ReportState(Context, PreviousState, "Patrol")
end

function Patrol.Tick(Context, DeltaTime)
    local Data = Context.mData
    local Owner = Context.mOwner
    local Location = Owner:GetActorLocation()
    local RemainingDistance = Data.mDestinationX - Location.X
    local Step = math.min(math.abs(RemainingDistance), Data.mPatrolSpeed * DeltaTime)
    local Direction = RemainingDistance < 0.0 and -1.0 or 1.0

    if Step > 0.0 and not Owner:Move(FVector.new(Direction * Step, 0.0, 0.0), Owner:GetActorRotation()) then
        error("[FSMExample] Patrol requires an actor with a root component")
    end

    if math.abs(Data.mDestinationX - Owner:GetActorLocation().X) <= 0.01 then
        Data.mDirection = -Data.mDirection
        Context.mMachine:RequestState("Idle")
    end
end

function Patrol.HandleEvent(Context, EventName, ...)
    Common.HandleInterruption(Context, EventName)
end

return Patrol
