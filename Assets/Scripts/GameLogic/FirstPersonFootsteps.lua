local FirstPersonFootsteps = {}
local Runtime = { mStates = {} }
local StepSounds = { "Assets/Sounds/FootstepLeft.wav", "Assets/Sounds/FootstepRight.wav" }

function FirstPersonFootsteps.Start(StateKey)
    if Runtime.mStates[StateKey] == nil then
        Runtime.mStates[StateKey] = { mHandles = {}, mFailed = false }
    end
end

function FirstPersonFootsteps.Update(StateKey)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return
    end

    for Index = #State.mHandles, 1, -1 do
        if not IsSoundPlaying(State.mHandles[Index]) then
            StopSound(State.mHandles[Index])
            table.remove(State.mHandles, Index)
        end
    end
end

function FirstPersonFootsteps.Step(StateKey, StepIndex, SpeedRatio, RunBlend, Impact)
    FirstPersonFootsteps.Start(StateKey)
    FirstPersonFootsteps.Update(StateKey)
    local State = Runtime.mStates[StateKey]
    if State.mFailed then
        return
    end

    local Volume = math.min(1.0, (0.58 + RunBlend * 0.22 + (Impact or 0.0) * 0.18) * math.min(1.0, SpeedRatio))
    local Handle = PlaySound(StepSounds[StepIndex % #StepSounds + 1], false, Volume)
    if Handle == 0 then
        State.mFailed = true
        Log("[PlayerFootsteps] Cannot play single-step sound")
        return
    end

    SetSoundPitch(Handle, 0.98 + RunBlend * 0.08 + StepIndex % 2 * 0.025)
    State.mHandles[#State.mHandles + 1] = Handle
end

function FirstPersonFootsteps.Stop(StateKey)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return
    end

    for _, Handle in ipairs(State.mHandles) do
        StopSound(Handle)
    end
    Runtime.mStates[StateKey] = nil
end

return FirstPersonFootsteps
