local GameManager = require("GameManager")
local Common = {}

function Common.ReportState(Context, PreviousState, StateName)
    Log("[FSM]", Context.mOwner:GetName(), PreviousState or "<none>", "->", StateName)
end

function Common.HandleInterruption(Context, EventName)
    if EventName == "Stun" and Context.mMachine:RequestState("Stunned") then
        Context.mData.mResumeState = Context.mMachine:GetCurrentState()
        Context.mData.mPatrolInterrupted = true
        Context.mData.mChaseInterrupted = true
    end
end

function Common.TryChase(Context)
    if GameManager.IsLightOn() and GameManager.GetPlayer() ~= nil then
        return Context.mMachine:RequestState("Chase")
    end
    return false
end

return Common
