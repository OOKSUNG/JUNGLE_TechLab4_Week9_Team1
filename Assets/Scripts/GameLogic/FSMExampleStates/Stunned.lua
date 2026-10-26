local Common = require("FSMExampleStates.Common")
local Stunned = {}

function Stunned.Enter(Context, PreviousState)
    Common.ReportState(Context, PreviousState, "Stunned")
end

function Stunned.Tick(Context, DeltaTime)
    if Context.mMachine:GetElapsedTime() >= Context.mData.mStunDuration then
        Context.mMachine:RequestState(Context.mData.mResumeState)
    end
end

return Stunned
