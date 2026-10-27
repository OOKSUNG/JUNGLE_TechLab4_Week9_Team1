local EndingCutscene = {}
local Runtime = { mPendingResult = nil, mState = nil, mSubject = nil, mGameScene = "Assets/Scenes/MapTest.scene" }

EndingCutscene.Config = {
    Car = { Scene = "Assets/Scenes/Ending_Car.scene", Duration = 12.0, Title = "차량 탈출", Subtitle = "엔진 소리가 어둠 속의 발소리를 지워 버렸다.", Epilogue = "백미러 속 시설이 멀어졌다. 이제 돌아갈 이유는 없다." },
    Door = { Scene = "Assets/Scenes/Ending_Door.scene", Duration = 11.0, Title = "비상문 탈출", Subtitle = "잠금이 풀렸다. 문틈 너머로 새벽 공기가 흘러들었다.", Epilogue = "문이 닫히자, 뒤쫓던 소리도 마침내 끊어졌다." },
}

local function Clamp(Value)
    return math.max(0.0, math.min(1.0, Value))
end

local function Smooth(Value)
    local Progress = Clamp(Value)
    return Progress * Progress * (3.0 - 2.0 * Progress)
end

local function Blend(First, Second, Progress)
    return First + (Second - First) * Progress
end

local function SetView(State, X, Y, Z, TargetX, TargetY, TargetZ, FieldOfView)
    local DeltaX = TargetX - X
    local DeltaY = TargetY - Y
    local Distance = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY)
    State.mView:SetActorLocation(FVector.new(X, Y, Z))
    State.mView:SetActorRotation(FRotator.new(math.deg(math.atan2(Z - TargetZ, Distance)), math.deg(math.atan2(DeltaY, DeltaX)), 0.0))
    State.mCamera:SetFieldOfView(FieldOfView)
end

local function UpdateCar(State)
    local Time = State.mElapsed
    local DrivingTime = math.max(0.0, Time - 2.2)
    local Distance = DrivingTime * DrivingTime * 0.72
    if Runtime.mSubject ~= nil then
        Runtime.mSubject:SetActorLocation(FVector.new(Distance, 0.0, math.sin(Time * 37.0) * 0.008))
    end
    if Time < 2.2 then
        local Progress = Smooth(Time / 2.2)
        SetView(State, Blend(5.6, 5.0, Progress), Blend(-7.2, -6.4, Progress), Blend(2.6, 2.4, Progress), 0.0, 0.0, 1.55, 48.0)
    elseif Time < 6.8 then
        local Progress = Smooth((Time - 2.2) / 4.6)
        SetView(State, Distance - 7.5, Blend(-4.5, -5.8, Progress), Blend(3.0, 3.5, Progress), Distance + 0.5, 0.0, 1.55, Blend(55.0, 62.0, Progress))
    else
        local Progress = Smooth((Time - 6.8) / 4.0)
        SetView(State, -7.0, -5.0, Blend(3.0, 4.5, Progress), Distance * 0.45 + 4.0, 0.0, 0.8, 54.0)
    end
end

local function UpdateDoor(State)
    local Time = State.mElapsed
    local Opening = Smooth((Time - 0.9) / 2.4)
    local Closing = Smooth((Time - 8.0) / 1.7)
    if Runtime.mSubject ~= nil then
        Runtime.mSubject:SetActorRotation(FRotator.new(0.0, -102.0 * Opening * (1.0 - Closing), 0.0))
    end
    if Time < 3.6 then
        local Progress = Smooth(Time / 3.6)
        SetView(State, Blend(-3.8, -2.7, Progress), 0.0, 1.65, 0.0, 0.0, 1.5, 58.0)
    elseif Time < 7.8 then
        local Progress = Smooth((Time - 3.6) / 4.2)
        local Step = math.sin((Time - 3.6) * math.pi * 4.0) * 0.018
        SetView(State, Blend(-2.7, 5.0, Progress), 0.0, 1.65 + Step, 16.0, 0.0, 1.75, Blend(58.0, 66.0, Progress))
    else
        local Progress = Smooth((Time - 7.8) / 2.0)
        SetView(State, Blend(5.0, 6.5, Progress), -3.0, 2.1, 0.0, 0.0, 1.5, 52.0)
    end
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

local function UpdateSound(State)
    if State.mRoute == "Door" then
        PlayCue(State, "Unlock", "Assets/Sounds/손전등키는소리.mp3", 0.4, 0.7)
        PlayCue(State, "Open", "Assets/Sounds/DoorOpen.wav", 0.9, 0.85)
        PlayCue(State, "Close", "Assets/Sounds/DoorClose.wav", 8.0, 0.85)
        for Index = 1, 8 do
            PlayCue(State, "Step" .. Index, Index % 2 == 1 and "Assets/Sounds/FootstepLeft.wav" or "Assets/Sounds/FootstepRight.wav", 3.9 + (Index - 1) * 0.48, 0.45)
        end
    else
        PlayCue(State, "DoorClose", "Assets/Sounds/DoorClose.wav", 0.15, 0.65)
        PlayCue(State, "Engine", "Assets/Sounds/EndingCarEngine.wav", 0.65, 0.7)
    end
end

local function StopSounds(State)
    for _, Handle in ipairs(State.mSounds) do
        StopSound(Handle)
    end
    State.mSounds = {}
end

function EndingCutscene.SetGameScene(Scene)
    Runtime.mGameScene = Scene
end

function EndingCutscene.ClearPending()
    Runtime.mPendingResult = nil
end

function EndingCutscene.Prepare(Route, Result)
    if EndingCutscene.Config[Route] == nil then
        return false
    end
    Runtime.mPendingResult = { Route = Route, ElapsedTime = Result.ElapsedTime, BatteriesUsed = Result.BatteriesUsed, GameScene = Runtime.mGameScene }
    return true
end

function EndingCutscene.GetPendingScene()
    local Result = Runtime.mPendingResult
    return Result ~= nil and EndingCutscene.Config[Result.Route].Scene or nil
end

function EndingCutscene.RegisterSubject(Actor)
    Runtime.mSubject = Actor
end

function EndingCutscene.UnregisterSubject(Actor)
    if Runtime.mSubject == Actor then
        Runtime.mSubject = nil
    end
end

function EndingCutscene.Start(View, Scene)
    EndingCutscene.Stop()
    local Route = Scene == "Ending_Car" and "Car" or "Door"
    local Result = Runtime.mPendingResult
    Runtime.mPendingResult = nil
    local State = { mView = View, mCamera = View:GetCamera(), mRoute = Route, mElapsed = 0.0, mFinished = false, mSounds = {}, mPlayedCues = {}, mResult = Result ~= nil and Result.Route == Route and Result or { Route = Route, ElapsedTime = 0.0, BatteriesUsed = 0, GameScene = "Assets/Scenes/MapTest.scene" } }
    Runtime.mState = State
    SetCursorMode(CursorMode.Free)
    EndingCutscene.Update(0.0)
end

function EndingCutscene.Update(DeltaTime)
    local State = Runtime.mState
    if State == nil or State.mFinished then
        return
    end
    State.mElapsed = math.min(EndingCutscene.Config[State.mRoute].Duration, State.mElapsed + math.max(0.0, DeltaTime))
    if State.mRoute == "Car" then
        UpdateCar(State)
    else
        UpdateDoor(State)
    end
    UpdateSound(State)
    if State.mElapsed >= EndingCutscene.Config[State.mRoute].Duration then
        EndingCutscene.Finish()
    end
end

function EndingCutscene.Finish()
    local State = Runtime.mState
    if State ~= nil and not State.mFinished then
        State.mFinished = true
        StopSounds(State)
        SetCursorMode(CursorMode.Free)
    end
end

function EndingCutscene.Stop()
    if Runtime.mState ~= nil then
        StopSounds(Runtime.mState)
        Runtime.mState = nil
    end
end

function EndingCutscene.GetState()
    return Runtime.mState
end

return EndingCutscene
