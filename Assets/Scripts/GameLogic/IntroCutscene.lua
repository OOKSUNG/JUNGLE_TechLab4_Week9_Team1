local IntroCutscene = {}
local Config = require("IntroData")
local Runtime = { mView = nil, mPlayerView = nil, mDoor = nil, mFade = nil, mState = nil }

IntroCutscene.Config = Config

local function Smooth(Value)
    local Progress = math.max(0.0, math.min(1.0, Value))
    return Progress * Progress * (3.0 - 2.0 * Progress)
end

local function Blend(First, Second, Progress)
    return First + (Second - First) * Progress
end

local function SetDoor(Opening)
    if Runtime.mDoor ~= nil then
        Runtime.mDoor:SetActorLocation(FVector.new(Config.Door.X, Config.Door.Y, Config.Door.Z + Config.DoorTravel * Opening))
    end
end

local function StopSounds(State)
    for _, Handle in ipairs(State.mSounds) do
        StopSound(Handle)
    end
    State.mSounds = {}
end

local function PlayCue(State, Name, Path, Time, Volume)
    if State.mElapsed >= Time and not State.mPlayedCues[Name] then
        State.mPlayedCues[Name] = true
        local Handle = PlaySound(Path, false, Volume)
        if Handle ~= 0 then
            State.mSounds[#State.mSounds + 1] = Handle
        end
    end
end

local function SetPlayerLocation(Player, X)
    Player:SetActorLocation(FVector.new(X, Config.Spawn.Y, Config.Spawn.Z))
    Player:SetActorRotation(FRotator.new(0.0, Config.Yaw, 0.0))
end

local function Start(Player)
    if Player == nil or Runtime.mView == nil or Runtime.mPlayerView == nil or Runtime.mDoor == nil or Runtime.mFade == nil then
        return false
    end
    local Manager = Runtime.mView:GetPlayerCameraManager()
    local Camera = Runtime.mPlayerView:GetCamera()
    if Manager == nil or Camera == nil then
        return false
    end
    if not Manager:SetViewTarget(Runtime.mView) then
        return false
    end
    local ViewModel = Camera:FindChildComponent("FlashlightMesh")
    local State = { mPlayer = Player, mManager = Manager, mCamera = Camera, mCameraLocation = Camera:GetRelativeLocation(), mViewModel = ViewModel, mViewModelLocation = ViewModel ~= nil and ViewModel:GetRelativeLocation() or nil, mElapsed = 0.0, mBlending = false, mFinished = false, mSounds = {}, mPlayedCues = {} }
    Runtime.mState = State
    SetPlayerLocation(Player, Config.Spawn.X)
    SetDoor(0.0)
    if ViewModel ~= nil then
        ViewModel:SetRelativeLocation(FVector.new(0.0, 0.0, -10.0))
    end
    Runtime.mFade:StopSequence()
    Runtime.mFade:PlaySequence()
    SetCursorMode(CursorMode.Locked)
    return true
end

function IntroCutscene.RegisterView(Actor)
    Runtime.mView = Actor
end

function IntroCutscene.RegisterPlayerView(Actor)
    Runtime.mPlayerView = Actor
end

function IntroCutscene.RegisterDoor(Actor)
    Runtime.mDoor = Actor
end

function IntroCutscene.RegisterFade(Actor)
    Runtime.mFade = Actor
end

function IntroCutscene.ReleaseActor(Actor)
    if Actor == Runtime.mView or Actor == Runtime.mPlayerView or (Runtime.mState ~= nil and Actor == Runtime.mState.mPlayer) then
        IntroCutscene.Stop()
    end
    for _, Field in ipairs({ "mView", "mPlayerView", "mDoor", "mFade" }) do
        if Runtime[Field] == Actor then
            Runtime[Field] = nil
        end
    end
end

function IntroCutscene.GetState()
    return Runtime.mState
end

function IntroCutscene.Finish()
    local State = Runtime.mState
    if State == nil or State.mFinished then
        return
    end
    SetPlayerLocation(State.mPlayer, Config.Destination.X)
    SetDoor(0.0)
    State.mCamera:SetRelativeLocation(State.mCameraLocation)
    State.mManager:SetViewTargetCamera(State.mCamera)
    if State.mViewModel ~= nil then
        State.mViewModel:SetRelativeLocation(State.mViewModelLocation)
    end
    if Runtime.mFade ~= nil then
        Runtime.mFade:StopSequence()
    end
    StopSounds(State)
    State.mFinished = true
end

function IntroCutscene.Update(DeltaTime, Player)
    if Runtime.mState == nil and not Start(Player) then
        return false
    end
    local State = Runtime.mState
    if State.mFinished then
        return true
    end
    State.mElapsed = math.min(Config.Duration, State.mElapsed + math.max(0.0, DeltaTime))
    local Time = State.mElapsed
    if Time >= Config.Duration then
        IntroCutscene.Finish()
        return true
    end
    local Approach = Smooth((Time - Config.WalkStart) / (Config.ApproachEnd - Config.WalkStart))
    local Entry = Smooth((Time - Config.ApproachEnd) / (Config.WalkEnd - Config.ApproachEnd))
    SetPlayerLocation(Player, Time < Config.ApproachEnd and Blend(Config.Spawn.X, 3.5, Approach) or Blend(3.5, Config.Destination.X, Entry))
    local Bob = Time > Config.WalkStart and Time < Config.WalkEnd and math.sin((Time - Config.WalkStart) * math.pi * 4.0) * 0.012 * math.sin(math.pi * (Time - Config.WalkStart) / (Config.WalkEnd - Config.WalkStart)) or 0.0
    State.mCamera:SetRelativeLocation(FVector.new(State.mCameraLocation.X, State.mCameraLocation.Y, State.mCameraLocation.Z + Bob))
    local Opening = Smooth((Time - Config.DoorOpenStart) / Config.DoorOpenDuration)
    local Closing = Smooth((Time - Config.DoorCloseStart) / Config.DoorCloseDuration)
    SetDoor(Opening * (1.0 - Closing))
    if not State.mBlending then
        local Dolly = Smooth(Time / Config.BlendStart)
        Runtime.mView:SetActorLocation(FVector.new(Blend(10.0, 7.8, Dolly), Blend(16.8, 15.6, Dolly), Blend(2.65, 2.15, Dolly)))
        Runtime.mView:SetActorRotation(FRotator.new(Blend(6.0, 2.0, Dolly), Blend(194.0, 187.0, Dolly), 0.0))
        if Time >= Config.BlendStart then
            State.mManager:SetViewTargetCamera(State.mCamera, Config.BlendDuration)
            State.mBlending = true
        end
    end
    PlayCue(State, "Open", "Assets/Sounds/DoorOpen.wav", Config.DoorOpenStart, 0.8)
    PlayCue(State, "Close", "Assets/Sounds/DoorClose.wav", Config.DoorCloseStart, 0.85)
    for Index = 1, 12 do
        PlayCue(State, "Step" .. Index, Index % 2 == 1 and "Assets/Sounds/FootstepLeft.wav" or "Assets/Sounds/FootstepRight.wav", Config.WalkStart + 0.35 + (Index - 1) * 0.5, 0.35)
    end
    return false
end

function IntroCutscene.Stop()
    local State = Runtime.mState
    if State ~= nil then
        if not State.mFinished then
            State.mManager:SetViewTargetCamera(State.mCamera)
            State.mCamera:SetRelativeLocation(State.mCameraLocation)
            if State.mViewModel ~= nil then
                State.mViewModel:SetRelativeLocation(State.mViewModelLocation)
            end
        end
        StopSounds(State)
    end
    if Runtime.mFade ~= nil then
        Runtime.mFade:StopSequence()
    end
    SetDoor(0.0)
    Runtime.mState = nil
end

return IntroCutscene
