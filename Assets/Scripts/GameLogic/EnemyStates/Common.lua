local Common = {}

function Common.ReportState(Context, PreviousState, StateName)
    Log("[FSM]", Context.mOwner:GetName(), PreviousState or "<none>", "->", StateName)
end

function Common.HandleInterruption(Context, EventName)
    if EventName == "Stun" and Context.mMachine:RequestState("Stunned") then
        Context.mData.mResumeState = Context.mMachine:GetCurrentState()
        Context.mData.mPatrolInterrupted = true
    end
end

return Common
