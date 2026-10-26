local WalkingCamera = {}
local Runtime = { mStates = {} }
local StrideLength = 2.4
local VerticalAmplitude = 0.006
local MaximumStepFrequency = 2.8
local BlendSpeed = 14.0
local PitchLimit = 85.0
local MinimumFieldOfView = 40.0
local MaximumFieldOfView = 85.0

function WalkingCamera.Stop(StateKey)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return
    end

    State.mCamera:SetRelativeLocation(State.mBaseLocation)
    State.mCamera:SetRelativeRotation(State.mBaseRotation)
    State.mCamera:SetFieldOfView(State.mBaseFieldOfView)
    Runtime.mStates[StateKey] = nil
end

function WalkingCamera.Start(StateKey, Actor, InitialPitch, HeadBobStrength)
    local PreviousState = Runtime.mStates[StateKey]
    local LookPitch = PreviousState and PreviousState.mLookPitch or InitialPitch or 0.0
    local PreviousFieldOfView = PreviousState and PreviousState.mFieldOfView or nil
    local MotionStrength = HeadBobStrength
    if MotionStrength == nil then
        MotionStrength = PreviousState and PreviousState.mHeadBobStrength or 0.0
    end
    WalkingCamera.Stop(StateKey)

    local Camera = Actor:GetCamera()
    if Camera == nil then
        return 0.0
    end

    local BaseRotation = Camera:GetRelativeRotation()
    local BaseFieldOfView = Camera:GetFieldOfView()
    local FieldOfView = PreviousFieldOfView or BaseFieldOfView
    MotionStrength = math.max(0.0, math.min(1.0, MotionStrength))
    LookPitch = math.max(-PitchLimit - BaseRotation.Pitch, math.min(PitchLimit - BaseRotation.Pitch, LookPitch))
    Runtime.mStates[StateKey] = { mCamera = Camera, mBaseLocation = Camera:GetRelativeLocation(), mBaseRotation = BaseRotation, mBaseFieldOfView = BaseFieldOfView, mFieldOfView = FieldOfView, mHeadBobStrength = MotionStrength, mLookPitch = LookPitch, mPhase = 0.0, mBlend = 0.0 }
    Camera:SetRelativeRotation(FRotator.new(BaseRotation.Pitch + LookPitch, BaseRotation.Yaw, 0.0))
    Camera:SetFieldOfView(FieldOfView)
    return MotionStrength
end

function WalkingCamera.Look(StateKey, PitchDelta)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return
    end

    State.mLookPitch = math.max(-PitchLimit - State.mBaseRotation.Pitch, math.min(PitchLimit - State.mBaseRotation.Pitch, State.mLookPitch + PitchDelta))
end

function WalkingCamera.SetHeadBobStrength(StateKey, Strength)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return
    end

    State.mHeadBobStrength = math.max(0.0, math.min(1.0, Strength))
    if State.mHeadBobStrength == 0.0 then
        State.mPhase = 0.0
        State.mBlend = 0.0
        State.mCamera:SetRelativeLocation(State.mBaseLocation)
    end
end

function WalkingCamera.AdjustFieldOfView(StateKey, Delta)
    local State = Runtime.mStates[StateKey]
    if State == nil then
        return nil
    end

    State.mFieldOfView = math.max(MinimumFieldOfView, math.min(MaximumFieldOfView, State.mFieldOfView + Delta))
    State.mCamera:SetFieldOfView(State.mFieldOfView)
    return State.mFieldOfView
end

function WalkingCamera.Update(StateKey, LocalMovement, MoveSpeed, DeltaTime)
    local State = Runtime.mStates[StateKey]
    if State == nil or DeltaTime <= 0.0 or MoveSpeed <= 0.0 then
        return
    end

    local BobOffset = 0.0
    if State.mHeadBobStrength > 0.0 then
        local ReferenceDistance = MoveSpeed * DeltaTime
        local Distance = math.min(ReferenceDistance, math.sqrt(LocalMovement.X * LocalMovement.X + LocalMovement.Y * LocalMovement.Y))
        local TargetBlend = Distance / ReferenceDistance
        local BlendAlpha = 1.0 - math.exp(-BlendSpeed * DeltaTime)
        State.mBlend = State.mBlend + (TargetBlend - State.mBlend) * BlendAlpha
        local PhaseStep = math.min(Distance * math.pi * 2.0 / StrideLength, MaximumStepFrequency * math.pi * DeltaTime)
        State.mPhase = (State.mPhase + PhaseStep) % (math.pi * 2.0)

        if TargetBlend == 0.0 and State.mBlend < 0.0001 then
            State.mBlend = 0.0
            State.mPhase = 0.0
        end

        BobOffset = math.sin(State.mPhase * 2.0) * VerticalAmplitude * State.mHeadBobStrength * State.mBlend
    else
        State.mBlend = 0.0
        State.mPhase = 0.0
    end

    local BaseLocation = State.mBaseLocation
    local BaseRotation = State.mBaseRotation
    local Pitch = BaseRotation.Pitch + State.mLookPitch
    State.mCamera:SetRelativeLocation(FVector.new(BaseLocation.X, BaseLocation.Y, BaseLocation.Z + BobOffset))
    State.mCamera:SetRelativeRotation(FRotator.new(Pitch, BaseRotation.Yaw, 0.0))
end

return WalkingCamera
