package.path = "Assets/Scripts/GameLogic/?.lua;" .. package.path

FVector = {}
FVector2 = {}
FRotator = {}
CursorMode = { Free = 0, Locked = 1 }
Key = { Space = 1, Enter = 2, R = 3 }
MouseButton = { Left = 1 }

function FVector.new(X, Y, Z)
    return { X = X, Y = Y, Z = Z }
end

function FVector2.new(X, Y)
    return { X = X, Y = Y }
end

function FRotator.new(Pitch, Yaw, Roll)
    return { Pitch = Pitch, Yaw = Yaw, Roll = Roll }
end

local Runtime = { mSounds = {}, mNextHandle = 0, mPressed = nil, mLoads = {}, mPassed = 0 }

function SetCursorMode(Mode)
end

function PlaySound(Path, Loop, Volume)
    Runtime.mNextHandle = Runtime.mNextHandle + 1
    Runtime.mSounds[Runtime.mNextHandle] = Path
    return Runtime.mNextHandle
end

function StopSound(Handle)
    Runtime.mSounds[Handle] = nil
end

function IsKeyPressed(Value)
    return Runtime.mPressed == Value
end

function AddUIImage(Path, Size, Anchor, Alignment, Offset)
end

function AddUIText(Text, Size, Anchor, Alignment, Offset)
end

local Ending = require("EndingCutscene")
local GameManager = require("GameManager")
local View = { mCamera = {}, mLocation = nil, mRotation = nil }
local Subject = { mLocation = nil, mRotation = nil }

function View.GetCamera(Self)
    return Self.mCamera
end

function View.SetActorLocation(Self, Location)
    Self.mLocation = Location
end

function View.SetActorRotation(Self, Rotation)
    Self.mRotation = Rotation
end

function View.mCamera.SetFieldOfView(Self, Value)
    Self.mFieldOfView = Value
end

Subject.SetActorLocation = View.SetActorLocation
Subject.SetActorRotation = View.SetActorRotation

local function Near(First, Second)
    assert(math.abs(First - Second) < 0.0001, tostring(First) .. " differs from " .. tostring(Second))
end

local function Test(Name, Run)
    Ending.Stop()
    Ending.UnregisterSubject(Subject)
    GameManager.StartGame()
    Runtime.mSounds = {}
    Runtime.mPressed = nil
    Runtime.mLoads = {}
    Run()
    Runtime.mPassed = Runtime.mPassed + 1
    print("PASS " .. Name)
end

Test("each escape freezes gameplay and preserves results across game teardown", function()
    for _, Route in ipairs({ "Car", "Door" }) do
        GameManager.StartGame()
        Ending.SetGameScene("Assets/Scenes/main.scene")
        GameManager.Tick(123.25)
        GameManager.AddBatteryUsed()
        GameManager.Escape(Route)
        assert(not GameManager.IsPlaying() and GameManager.Phase == GameManager.EPhase.Ending)
        assert(Ending.GetPendingScene() == "Assets/Scenes/Ending_" .. Route .. ".scene")
        GameManager.GameOver("LateCapture")
        GameManager.Escape(Route == "Car" and "Door" or "Car")
        GameManager.Tick(50.0)
        GameManager.Reset()
        Ending.Start(View, "Ending_" .. Route)
        local State = Ending.GetState()
        Near(State.mResult.ElapsedTime, 123.25)
        assert(State.mRoute == Route and State.mResult.BatteriesUsed == 1)
        assert(State.mResult.GameScene == "Assets/Scenes/main.scene")
        assert(Ending.GetPendingScene() == nil)
        Ending.Stop()
    end
end)

Test("car departs and finishes once while negative time does not rewind", function()
    Ending.RegisterSubject(Subject)
    Ending.Start(View, "Ending_Car")
    Ending.Update(-5.0)
    Near(Ending.GetState().mElapsed, 0.0)
    Ending.Update(5.0)
    assert(Subject.mLocation.X > 0.0 and next(Runtime.mSounds) ~= nil)
    Ending.Update(100.0)
    assert(Ending.GetState().mFinished and next(Runtime.mSounds) == nil)
    local X = Subject.mLocation.X
    Ending.Update(3.0)
    Near(Subject.mLocation.X, X)
end)

Test("door unlocks, opens, is crossed, and closes behind the camera", function()
    Ending.RegisterSubject(Subject)
    Ending.Start(View, "Ending_Door")
    Ending.Update(3.5)
    assert(Subject.mRotation.Yaw < -100.0 and View.mLocation.X < 0.0)
    Ending.Update(4.0)
    assert(View.mLocation.X > 0.0)
    Ending.Update(2.5)
    Near(Subject.mRotation.Yaw, 0.0)
    Ending.Update(1.0)
    assert(Ending.GetState().mFinished and next(Runtime.mSounds) == nil)
end)

Test("skip and interrupted scene cleanup stop all cues and release actors", function()
    Ending.RegisterSubject(Subject)
    Ending.Start(View, "Ending_Door")
    Ending.Update(4.0)
    assert(next(Runtime.mSounds) ~= nil)
    Ending.UnregisterSubject(Subject)
    Ending.Update(1.0)
    Ending.Finish()
    Ending.Finish()
    assert(Ending.GetState().mFinished and next(Runtime.mSounds) == nil)
    Ending.Stop()
    assert(Ending.GetState() == nil)
end)

Test("standalone scene preview and new games discard previous results", function()
    GameManager.Escape("Car")
    GameManager.StartGame()
    assert(Ending.GetPendingScene() == nil)
    Ending.Start(View, "Ending_Door")
    assert(Ending.GetState().mRoute == "Door")
    Near(Ending.GetState().mResult.ElapsedTime, 0.0)
    assert(Ending.GetState().mResult.BatteriesUsed == 0)
end)

Test("the skip key cannot also activate the result menu in the same frame", function()
    local Environment = { self = View, sceneName = "Ending_Car" }
    setmetatable(Environment, { __index = _G })
    function Environment.GetViewportSize()
        return FVector2.new(1280, 720)
    end
    function Environment.GetMousePosition()
        return FVector2.new(0, 0)
    end
    function Environment.IsMouseOverGameViewport()
        return false
    end
    function Environment.IsMousePressed(Value)
        return false
    end
    function Environment.LoadScene(Path)
        Runtime.mLoads[#Runtime.mLoads + 1] = Path
    end
    local Script = assert(loadfile("Assets/Scripts/GameLogic/EndingActor.lua"))
    setfenv(Script, Environment)
    Script()
    Environment.BeginPlay()
    Environment.Tick(1.0)
    Runtime.mPressed = Key.Enter
    Environment.Tick(0.016)
    assert(Ending.GetState().mFinished and #Runtime.mLoads == 0)
    Runtime.mPressed = nil
    Environment.Tick(0.016)
    Runtime.mPressed = Key.R
    Environment.Tick(0.016)
    assert(#Runtime.mLoads == 1 and Runtime.mLoads[1] == "Assets/Scenes/MapTest.scene")
    Environment.Tick(0.016)
    assert(#Runtime.mLoads == 1)
    Environment.EndPlay()
    assert(Ending.GetState() == nil)
end)

Ending.Stop()
GameManager.Reset()
print("Ending tests passed: " .. Runtime.mPassed)
