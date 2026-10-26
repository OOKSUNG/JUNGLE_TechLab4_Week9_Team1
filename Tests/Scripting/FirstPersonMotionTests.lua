package.path = "Assets/Scripts/GameLogic/?.lua;" .. package.path

local Audio = { mNextHandle = 0, mSounds = {}, mPlayed = {}, mTime = 0.0, mFails = false, mErrors = 0 }
FVector = { new = function(X, Y, Z) return { X = X, Y = Y, Z = Z } end }
FRotator = { new = function(Pitch, Yaw, Roll) return { Pitch = Pitch, Yaw = Yaw, Roll = Roll } end }

function PlaySound(Path, Loop, Volume)
    assert(not Loop, "Footsteps must be single shots")
    if Audio.mFails then
        return 0
    end
    Audio.mNextHandle = Audio.mNextHandle + 1
    Audio.mSounds[Audio.mNextHandle] = Audio.mTime + 0.3
    Audio.mPlayed[#Audio.mPlayed + 1] = { Path = Path, Volume = Volume, Time = Audio.mTime }
    return Audio.mNextHandle
end

function StopSound(Handle)
    Audio.mSounds[Handle] = nil
end

function IsSoundPlaying(Handle)
    return Audio.mSounds[Handle] ~= nil and Audio.mSounds[Handle] > Audio.mTime
end

function SetSoundPitch(Handle, Pitch)
    assert(Pitch >= 0.9 and Pitch <= 1.2)
end

function Log(Message)
    Audio.mErrors = Audio.mErrors + 1
end

local function CopyVector(Value)
    return FVector.new(Value.X, Value.Y, Value.Z)
end

local function CopyRotation(Value)
    return FRotator.new(Value.Pitch, Value.Yaw, Value.Roll)
end

local function CreateComponent(X, Y, Z, Yaw)
    local Component = { mLocation = FVector.new(X, Y, Z), mRotation = FRotator.new(0.0, Yaw or 0.0, 0.0), mFieldOfView = 60.0, mChildren = {} }
    function Component:GetRelativeLocation()
        return CopyVector(self.mLocation)
    end
    function Component:SetRelativeLocation(Value)
        self.mLocation = CopyVector(Value)
    end
    function Component:GetRelativeRotation()
        return CopyRotation(self.mRotation)
    end
    function Component:SetRelativeRotation(Value)
        self.mRotation = CopyRotation(Value)
    end
    function Component:GetFieldOfView()
        return self.mFieldOfView
    end
    function Component:SetFieldOfView(Value)
        self.mFieldOfView = Value
    end
    function Component:FindChildComponent(Name)
        if self.mChildren[Name] ~= nil then
            return self.mChildren[Name]
        end
        for _, Child in pairs(self.mChildren) do
            local Found = Child:FindChildComponent(Name)
            if Found ~= nil then
                return Found
            end
        end
        return nil
    end
    return Component
end

local function CreatePlayer(WithCamera, WithModel)
    local Camera = WithCamera and CreateComponent(0.0, 0.0, 1.4) or nil
    local Model = WithModel and CreateComponent(0.49, 0.2, -0.09, 90.0) or nil
    local Light = WithModel and CreateComponent(0.0, 0.0, 0.0) or nil
    if Camera ~= nil then
        Camera.mChildren = { FlashlightMesh = Model, USpotLightComponent_0 = Light }
    end
    local Player = { mHeight = 0.5, mCamera = Camera }
    function Player:GetCamera()
        return self.mCamera
    end
    function Player:GetActorLocation()
        return FVector.new(0.0, 0.0, self.mHeight)
    end
    return Player, Camera, Model, Light
end

local WalkingCamera = require("WalkingCamera")
local Footsteps = require("FirstPersonFootsteps")
local function Advance(Key, X, Y, Speed, Frames, Rate, Running, Active)
    for Frame = 1, Frames do
        Audio.mTime = Audio.mTime + 1.0 / Rate
        WalkingCamera.Update(Key, FVector.new(X / Rate, Y / Rate, 0.0), Speed, 1.0 / Rate, Running, Active)
    end
end

local function Near(Actual, Expected, Tolerance)
    assert(math.abs(Actual - Expected) <= Tolerance, string.format("Expected %.8f, received %.8f", Expected, Actual))
end

for Index, Direction in ipairs({ { 3.0, 0.0 }, { -3.0, 0.0 }, { 0.0, 3.0 }, { 0.0, -3.0 }, { 3.0 / math.sqrt(2.0), 3.0 / math.sqrt(2.0) } }) do
    local Key = "Direction" .. Index
    local Player, Camera, Model, Light = CreatePlayer(true, true)
    WalkingCamera.Start(Key, Player, 0.0)
    local MinimumZ = 10.0
    local MaximumZ = -10.0
    local MinimumModelY = 10.0
    local MaximumModelY = -10.0
    local InitialSoundCount = #Audio.mPlayed
    for Frame = 1, 180 do
        Advance(Key, Direction[1], Direction[2], 3.0, 1, 60)
        MinimumZ = math.min(MinimumZ, Camera.mLocation.Z)
        MaximumZ = math.max(MaximumZ, Camera.mLocation.Z)
        MinimumModelY = math.min(MinimumModelY, Model.mLocation.Y)
        MaximumModelY = math.max(MaximumModelY, Model.mLocation.Y)
        Near(Camera.mRotation.Roll, 0.0, 0.0)
        Footsteps.Update(Key)
    end
    assert(MaximumZ - MinimumZ > 0.02)
    assert(MaximumModelY - MinimumModelY > 0.025)
    assert(#Audio.mPlayed - InitialSoundCount == WalkingCamera.GetMotionState(Key).StepCount)
    local StepsBeforeWall = #Audio.mPlayed
    Advance(Key, 0.0, 0.0, 3.0, 120, 60)
    assert(#Audio.mPlayed == StepsBeforeWall)
    Near(Camera.mLocation.Z, 1.4, 0.000001)
    Advance(Key, 0.0, 0.0, 0.0, 120, 60, false, false)
    Near(Model.mLocation.Z, -0.09, 0.000001)
    WalkingCamera.Stop(Key)
    Near(Model.mLocation.Y, 0.2, 0.0)
    Near(Model.mRotation.Yaw, 90.0, 0.0)
    Near(Light.mLocation.Z, 0.0, 0.0)
end
print("PASS: all movement directions, camera/model motion, shared step timing, walls, stop and restoration")

local Reference = nil
for _, Rate in ipairs({ 30, 60, 144 }) do
    local Key = "Rate" .. Rate
    local Player, Camera, Model = CreatePlayer(true, true)
    WalkingCamera.Start(Key, Player, 0.0)
    Advance(Key, 3.0, 0.0, 3.0, Rate * 4, Rate)
    local Motion = WalkingCamera.GetMotionState(Key)
    if Reference == nil then
        Reference = { Progress = Motion.StepProgress, Steps = Motion.StepCount, CameraZ = Camera.mLocation.Z, ModelY = Model.mLocation.Y }
    else
        Near(Motion.StepProgress, Reference.Progress, 0.0000001)
        Near(Motion.StepCount, Reference.Steps, 0.0)
        Near(Camera.mLocation.Z, Reference.CameraZ, 0.001)
        Near(Model.mLocation.Y, Reference.ModelY, 0.001)
    end
    WalkingCamera.Stop(Key)
end
print("PASS: 30/60/144 FPS gait and motion consistency")

local Player, Camera, Model, Light = CreatePlayer(true, true)
WalkingCamera.Start("Controls", Player, 0.0)
WalkingCamera.SetHeadBobStrength("Controls", 0.0)
Advance("Controls", 3.0, 0.0, 3.0, 60, 60)
Near(Camera.mLocation.Z, 1.4, 0.0)
assert(math.abs(Model.mLocation.Y - 0.2) > 0.001)
WalkingCamera.SetViewModelStrength("Controls", 0.0)
Advance("Controls", 3.0, 0.0, 3.0, 60, 60)
Near(Model.mLocation.Y, 0.2, 0.0)
assert(math.abs(Light.mLocation.Y) > 0.00001)
WalkingCamera.SetLightMotionStrength("Controls", 0.0)
Advance("Controls", 3.0, 0.0, 3.0, 60, 60)
Near(Light.mLocation.Y, 0.0, 0.0)
assert(WalkingCamera.SetHeadBobStrength("Controls", 10.0) == 10.0)
assert(WalkingCamera.SetViewModelStrength("Controls", -1.0) == 0.0)
Advance("Controls", 0.0, 0.0, 0.0, 120, 60)
WalkingCamera.Look("Controls", 24.0, 30.0)
Near(Camera.mRotation.Pitch, 24.0, 0.0)
WalkingCamera.SetViewModelStrength("Controls", 1.0)
Advance("Controls", 0.0, 0.0, 0.0, 4, 60)
Near(Model.mRotation.Yaw, 90.0, 0.000001)
WalkingCamera.Look("Controls", 1000.0, 0.0)
Near(Camera.mRotation.Pitch, 85.0, 0.0)
assert(WalkingCamera.AdjustFieldOfView("Controls", 1000.0) == 85.0)
local CameraStrength, ModelStrength, LightStrength = WalkingCamera.Start("Controls", Player, 0.0)
Near(CameraStrength, 10.0, 0.0)
Near(ModelStrength, 1.0, 0.0)
Near(LightStrength, 0.0, 0.0)
Near(Camera.mRotation.Pitch, 85.0, 0.0)
Near(Camera.mFieldOfView, 85.0, 0.0)
WalkingCamera.Stop("Controls")
Near(Camera.mFieldOfView, 60.0, 0.0)
Near(Camera.mLocation.Z, 1.4, 0.0)
print("PASS: independent effect controls, immediate look, clamps and reload without drift")

local TurningPlayer, TurningCamera, TurningModel = CreatePlayer(true, true)
WalkingCamera.Start("Turning", TurningPlayer, 0.0)
for Frame = 1, 60 do
    WalkingCamera.Look("Turning", 0.0, 2.0)
    Advance("Turning", 0.0, 0.0, 3.0, 1, 60)
    Near(TurningModel.mRotation.Yaw, 90.0, 0.000001)
    Near(TurningModel.mRotation.Pitch, 0.0, 0.000001)
end
assert(TurningModel.mLocation.Y < 0.199)
Advance("Turning", 0.0, 0.0, 3.0, 60, 60)
Near(TurningModel.mRotation.Yaw, 90.0, 0.000001)
Near(TurningModel.mLocation.Y, 0.2, 0.000001)
WalkingCamera.Stop("Turning")
print("PASS: turn inertia affects position without delayed flashlight or beam rotation")

local function LensDirection(Rotation, LensYaw)
    local Pitch = math.rad(Rotation.Pitch)
    local Yaw = math.rad(Rotation.Yaw)
    local Roll = math.rad(Rotation.Roll)
    local LocalX = math.cos(math.rad(LensYaw))
    local LocalY = math.sin(math.rad(LensYaw))
    local TiltedX = math.cos(Pitch) * LocalX + math.sin(Pitch) * math.sin(Roll) * LocalY
    local TiltedY = math.cos(Roll) * LocalY
    return FVector.new(math.cos(Yaw) * TiltedX - math.sin(Yaw) * TiltedY, math.sin(Yaw) * TiltedX + math.cos(Yaw) * TiltedY, -math.sin(Pitch) * LocalX + math.cos(Pitch) * math.sin(Roll) * LocalY)
end

local AlignedPlayer, AlignedCamera, AlignedModel = CreatePlayer(true, true)
local RotatedPlayer, RotatedCamera, RotatedModel = CreatePlayer(true, true)
AlignedModel:SetRelativeRotation(FRotator.new(0.0, 0.0, 0.0))
WalkingCamera.Start("AlignedAxes", AlignedPlayer, 0.0)
WalkingCamera.Start("RotatedAxes", RotatedPlayer, 0.0)
for Frame = 1, 360 do
    local Moving = Frame <= 240
    local Speed = Frame <= 120 and 3.0 or 5.0
    Advance("AlignedAxes", Moving and Speed or 0.0, 0.0, Speed, 1, 60, Frame > 120)
    Advance("RotatedAxes", Moving and Speed or 0.0, 0.0, Speed, 1, 60, Frame > 120)
    local AlignedDirection = LensDirection(AlignedModel.mRotation, 0.0)
    local RotatedDirection = LensDirection(RotatedModel.mRotation, -90.0)
    Near(RotatedDirection.X, AlignedDirection.X, 0.000001)
    Near(RotatedDirection.Y, AlignedDirection.Y, 0.000001)
    Near(RotatedDirection.Z, AlignedDirection.Z, 0.000001)
end
WalkingCamera.Stop("AlignedAxes")
WalkingCamera.Stop("RotatedAxes")
print("PASS: flashlight lens motion uses camera axes regardless of authored mesh orientation")

local AttachedPlayer, AttachedCamera, AttachedModel, AttachedLight = CreatePlayer(true, true)
AttachedCamera.mChildren.USpotLightComponent_0 = nil
AttachedModel.mChildren.USpotLightComponent_0 = AttachedLight
AttachedLight:SetRelativeLocation(FVector.new(-14.13, -1.43, -1.94))
AttachedLight:SetRelativeRotation(FRotator.new(3.0, -90.0, 2.0))
WalkingCamera.Start("Attached", AttachedPlayer, 0.0)
for Frame = 1, 180 do
    WalkingCamera.Look("Attached", 0.1, 0.2)
    Advance("Attached", 3.0, 0.0, 3.0, 1, 60, Frame > 90)
    Near(AttachedLight.mLocation.X, -14.13, 0.0)
    Near(AttachedLight.mLocation.Y, -1.43, 0.0)
    Near(AttachedLight.mLocation.Z, -1.94, 0.0)
    Near(AttachedLight.mRotation.Pitch, 3.0, 0.0)
    Near(AttachedLight.mRotation.Yaw, -90.0, 0.0)
    Near(AttachedLight.mRotation.Roll, 2.0, 0.0)
end
WalkingCamera.SetLightMotionStrength("Attached", 0.0)
WalkingCamera.SetLightMotionStrength("Attached", 2.0)
Advance("Attached", 3.0, 0.0, 3.0, 60, 60)
Near(AttachedLight.mLocation.Y, -1.43, 0.0)
Near(AttachedLight.mRotation.Yaw, -90.0, 0.0)
WalkingCamera.Stop("Attached")
print("PASS: attached spotlight preserves authored local pose during walking, running, turning and light controls")

local LandingPlayer, LandingCamera, LandingModel = CreatePlayer(true, true)
WalkingCamera.Start("Landing", LandingPlayer, 0.0)
local BeforeLanding = #Audio.mPlayed
for Frame = 1, 8 do
    LandingPlayer.mHeight = LandingPlayer.mHeight - 0.05
    Advance("Landing", 3.0, 0.0, 3.0, 1, 60)
end
assert(#Audio.mPlayed == BeforeLanding)
Advance("Landing", 0.0, 0.0, 0.0, 1, 60)
assert(#Audio.mPlayed == BeforeLanding + 1)
assert(LandingCamera.mLocation.Z < 1.4)
assert(LandingModel.mLocation.Z < -0.09)
WalkingCamera.OnHit("Landing", { ImpactNormal = FVector.new(0.0, 0.0, 1.0) })
assert(#Audio.mPlayed == BeforeLanding + 1)
Advance("Landing", 0.0, 0.0, 0.0, 120, 60)
Near(LandingCamera.mLocation.Z, 1.4, 0.000001)
LandingPlayer.mHeight = LandingPlayer.mHeight - 10.0
Advance("Landing", 0.0, 0.0, 0.0, 2, 60)
assert(#Audio.mPlayed == BeforeLanding + 1)
WalkingCamera.Stop("Landing")
print("PASS: airborne footsteps suppressed, one landing impulse, recovery and teleport rejection")

local JumpPlayer = CreatePlayer(true, true)
WalkingCamera.Start("Jump", JumpPlayer, 0.0)
local BeforeJump = #Audio.mPlayed
for Frame = 1, 8 do
    JumpPlayer.mHeight = JumpPlayer.mHeight + 0.05
    Advance("Jump", 3.0, 0.0, 3.0, 1, 60)
end
Advance("Jump", 3.0, 0.0, 3.0, 30, 60)
assert(#Audio.mPlayed == BeforeJump)
assert(WalkingCamera.GetMotionState("Jump").IsAirborne)
for Frame = 1, 8 do
    JumpPlayer.mHeight = JumpPlayer.mHeight - 0.05
    Advance("Jump", 3.0, 0.0, 3.0, 1, 60)
end
Advance("Jump", 0.0, 0.0, 0.0, 1, 60)
assert(#Audio.mPlayed == BeforeJump + 1)
assert(not WalkingCamera.GetMotionState("Jump").IsAirborne)
WalkingCamera.Stop("Jump")
print("PASS: no phantom grounded footsteps at the top of a vertical arc")

local RunPlayer, RunCamera, RunModel = CreatePlayer(true, true)
WalkingCamera.Start("Run", RunPlayer, 0.0)
Advance("Run", 5.0, 0.0, 5.0, 120, 60, true)
assert(WalkingCamera.GetMotionState("Run").RunBlend > 0.99)
assert(RunModel.mLocation.Z < -0.10)
Near(RunCamera.mFieldOfView, 60.0, 0.0)
local BeforePause = #Audio.mPlayed
Advance("Run", 5.0, 0.0, 5.0, 120, 60, true, false)
assert(#Audio.mPlayed == BeforePause)
Near(RunCamera.mLocation.Z, 1.4, 0.000001)
WalkingCamera.Stop("Run")
local BarePlayer = CreatePlayer(true, false)
WalkingCamera.Start("Bare", BarePlayer, 0.0)
Advance("Bare", 3.0, 0.0, 3.0, 60, 60)
WalkingCamera.Update("Bare", FVector.new(0.0, 0.0, 0.0), 0.0, 0.0)
WalkingCamera.Stop("Bare")
local MissingPlayer = CreatePlayer(false, false)
assert(WalkingCamera.Start("Missing", MissingPlayer, 0.0) == 0.0)
Advance("Missing", 3.0, 0.0, 3.0, 60, 60)
WalkingCamera.Stop("Missing")
assert(next(Audio.mSounds) == nil)
print("PASS: run posture, fixed FOV, pause, absent components, zero delta and sound cleanup")
