local Common = {}

function Common.ReportState(Context, PreviousState, StateName)
    Log("[FSM]", Context.mOwner:GetName(), PreviousState or "<none>", "->", StateName)
end

function Common.HandleInterruption(Context, EventName)
    if EventName == "Stun" or EventName == "OnOverlap" or EventName == "OnHit" then
        Context.mData.mResumeState = Context.mMachine:GetCurrentState()
        Context.mMachine:RequestState("Stunned")
    end
end

return Common
