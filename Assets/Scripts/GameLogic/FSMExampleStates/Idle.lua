local Common = require("FSMExampleStates.Common")
local Idle = {}

function Idle.Enter(Context, PreviousState)
    Common.ReportState(Context, PreviousState, "Idle")
end

function Idle.Tick(Context, DeltaTime)
    if Context.mMachine:GetElapsedTime() >= Context.mData.mIdleDuration then
        Context.mMachine:RequestState("Patrol")
    end
end

function Idle.HandleEvent(Context, EventName, ...)
    Common.HandleInterruption(Context, EventName)
end

return Idle
