package.path = "Assets/Scripts/GameLogic/?.lua;" .. package.path

FVector = {}
FRotator = {}

function FVector.new(X, Y, Z)
    return { X = X, Y = Y, Z = Z }
end

function FRotator.new(Pitch, Yaw, Roll)
    return { Pitch = Pitch, Yaw = Yaw, Roll = Roll }
end

local Runtime = { mPlayed = 0, mStopped = 0, mPassed = 0, mPitch = 0.0 }

function PlaySound(Path, Loop, Volume)
    assert(Path == "Assets/Sounds/울음소리.mp3" and not Loop and Volume > 0.0)
    Runtime.mPlayed = Runtime.mPlayed + 1
    return Runtime.mPlayed
end

function StopSound(Handle)
    assert(Handle > 0)
    Runtime.mStopped = Runtime.mStopped + 1
end

function SetSoundPitch(Handle, Pitch)
    Runtime.mPitch = Pitch
end

local JumpScare = require("JumpScare")
local GameManager = require("GameManager")
local Actor = {}
Actor.__index = Actor

function Actor.Equals(Left, Right)
    return rawequal(Left.mIdentity or Left, Right.mIdentity or Right)
end

Actor.__eq = Actor.Equals

function Actor.New(X, Y, Z)
    return setmetatable({ mLocation = FVector.new(X, Y, Z), mRotation = FRotator.new(0.0, 0.0, 0.0), mScale = FVector.new(1.0, 1.0, 1.0), mCamera = nil, mLight = nil }, Actor)
end

function Actor:GetActorLocation()
    return FVector.new(self.mLocation.X, self.mLocation.Y, self.mLocation.Z)
end

function Actor:SetActorLocation(Location)
    self.mLocation = Location
end

function Actor:GetActorRotation()
    return FRotator.new(self.mRotation.Pitch, self.mRotation.Yaw, self.mRotation.Roll)
end

function Actor:SetActorRotation(Rotation)
    self.mRotation = Rotation
end

function Actor:GetActorScale3D()
    return self.mScale
end

function Actor:GetCamera()
    return self.mCamera
end

function Actor:GetSpotLight()
    return self.mLight
end

local function CreateCamera()
    local Camera = { mLocation = FVector.new(0.0, 0.0, 1.4), mRotation = FRotator.new(23.0, 0.0, 0.0), mFieldOfView = 72.0 }
    Camera.GetRelativeLocation = Actor.GetActorLocation
    Camera.SetRelativeLocation = Actor.SetActorLocation
    Camera.GetRelativeRotation = Actor.GetActorRotation
    Camera.SetRelativeRotation = Actor.SetActorRotation
    return Camera
end

local CameraMethods = {}

function CameraMethods.GetFieldOfView(Self)
    return Self.mFieldOfView
end

function CameraMethods.SetFieldOfView(Self, FieldOfView)
    Self.mFieldOfView = FieldOfView
end

function CameraMethods.FindChildComponent(Self, Name)
    return nil
end

local function Near(Actual, Expected)
    assert(math.abs(Actual - Expected) < 0.00001, tostring(Actual) .. " ~= " .. tostring(Expected))
end

local function Reset()
    GameManager.Reset()
    GameManager.StartGame()
    Runtime.mPlayed = 0
    Runtime.mStopped = 0
    local Player = Actor.New(10.0, 20.0, 0.5)
    local View = Actor.New(10.0, 20.0, 1.9)
    local Enemy = Actor.New(10.0, 21.0, 0.0)
    local Camera = setmetatable(CreateCamera(), { __index = CameraMethods })
    Player.mCamera = Camera
    View.mCamera = Camera
    GameManager.RegisterPlayer(Player)
    GameManager.RegisterEnemy(Enemy)
    JumpScare.RegisterView(View)
    return Player, View, Enemy, Camera
end

local function Test(Name, Run)
    local Player, View, Enemy, Camera = Reset()
    Run(Player, View, Enemy, Camera)
    Runtime.mPassed = Runtime.mPassed + 1
    print("PASS " .. Name)
end

local function FaceLocation(Enemy, Profile)
    local Angle = math.rad(Enemy.mRotation.Yaw)
    local Offset = Profile.FaceOffset
    local Scale = Enemy.mScale
    return FVector.new(Enemy.mLocation.X + math.cos(Angle) * Offset.X * Scale.X - math.sin(Angle) * Offset.Y * Scale.Y, Enemy.mLocation.Y + math.sin(Angle) * Offset.X * Scale.X + math.cos(Angle) * Offset.Y * Scale.Y, Enemy.mLocation.Z + Offset.Z * Scale.Z)
end

Test("killer lunges toward the camera with its face centered", function(Player, View, Enemy, Camera)
    GameManager.Tick(4.0)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    assert(GameManager.IsJumpScaring() and not GameManager.IsPlaying())
    local InitialFace = FaceLocation(Enemy, JumpScare.Config.Profiles.Monster)
    Near(InitialFace.X, 10.0)
    Near(InitialFace.Y, 20.0 + JumpScare.Config.StartDistance)
    Near(InitialFace.Z, 1.9)
    GameManager.Tick(JumpScare.Config.LungeDuration)
    local FinalFace = FaceLocation(Enemy, JumpScare.Config.Profiles.Monster)
    Near(FinalFace.X, 10.0)
    Near(FinalFace.Y, 20.0 + JumpScare.Config.EndDistance)
    Near(FinalFace.Z, 1.9)
    Near(Camera.mFieldOfView, JumpScare.Config.FieldOfView)
    Near(GameManager.ElapsedTime, 4.0)
    assert(Runtime.mPlayed == 1 and Runtime.mPitch == JumpScare.Config.SoundPitch)
end)

Test("watcher faces the lunge direction after its asset is rotated", function(Player, View, Enemy)
    GameManager.RegisterEnemy(Enemy, nil, "Watcher")
    Enemy.mScale = FVector.new(1.5, 0.8, 1.2)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    GameManager.Tick(JumpScare.Config.LungeDuration)
    local Face = FaceLocation(Enemy, JumpScare.Config.Profiles.Watcher)
    Near(Enemy.mRotation.Yaw, 270.0)
    Near(View.mLocation.Z, 1.9 + JumpScare.Config.Profiles.Watcher.CameraHeight)
    assert(View.mRotation.Pitch > 0.0)
    Near(Face.X, 10.0)
    Near(Face.Y, 20.0 + JumpScare.Config.EndDistance)
    Near(Face.Z, 1.9)
end)

Test("first killer wins when multiple overlap callbacks arrive", function(Player, View, Enemy)
    local OtherEnemy = Actor.New(10.0, 19.0, 0.0)
    GameManager.RegisterEnemy(OtherEnemy, nil, "Watcher")
    GameManager.GameOver("First", Enemy)
    GameManager.GameOver("Second", OtherEnemy)
    assert(GameManager.GameOverReason == "First" and Runtime.mPlayed == 1)
    Near(OtherEnemy.mLocation.Y, 19.0)
end)

Test("a collision wrapper for the same actor keeps the watcher face profile", function(Player, View, Enemy)
    GameManager.RegisterEnemy(Enemy, nil, "Watcher")
    local CollisionActor = setmetatable({ mIdentity = Enemy }, Actor)
    assert(CollisionActor == Enemy and not rawequal(CollisionActor, Enemy))
    assert(GameManager.EnemyScareProfiles[CollisionActor] == nil)
    GameManager.GameOver("CaughtByWatcher", CollisionActor)
    assert(GameManager.IsJumpScaring())
    GameManager.Tick(JumpScare.Config.LungeDuration)
    local Face = FaceLocation(Enemy, JumpScare.Config.Profiles.Watcher)
    Near(Face.Z, 1.9)
    Near(View.mLocation.Z, 1.9 + JumpScare.Config.Profiles.Watcher.CameraHeight)
end)

Test("registration and removal through another wrapper use the registered actor", function(Player, View, Enemy)
    local OtherWrapper = setmetatable({ mIdentity = Enemy }, Actor)
    GameManager.RegisterEnemy(OtherWrapper, nil, "Watcher")
    assert(#GameManager.GetEnemies() == 1)
    assert(GameManager.EnemyScareProfiles[Enemy] == "Watcher")
    GameManager.GameOver("CaughtByWatcher", OtherWrapper)
    Near(View.mLocation.Z, 1.9 + JumpScare.Config.Profiles.Watcher.CameraHeight)
    GameManager.UnregisterEnemy(OtherWrapper)
    assert(#GameManager.GetEnemies() == 0 and GameManager.EnemyScareProfiles[Enemy] == nil)
end)

Test("result waits for the closeup and blackout, and sound stops once", function(Player, View, Enemy)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    GameManager.Tick(0.9)
    assert(GameManager.IsJumpScaring() and not JumpScare.IsBlackout())
    GameManager.Tick(0.1)
    assert(GameManager.IsJumpScaring() and JumpScare.IsBlackout())
    assert(Runtime.mStopped == 1)
    GameManager.Tick(0.2)
    assert(GameManager.Phase == GameManager.EPhase.GameOver and JumpScare.IsBlackout())
    GameManager.Tick(5.0)
    assert(Runtime.mStopped == 1)
end)

Test("reset restores enemy transform, camera pose, field of view and sound", function(Player, View, Enemy, Camera)
    Enemy.mRotation = FRotator.new(0.0, 33.0, 0.0)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    GameManager.Tick(0.4)
    GameManager.Reset()
    Near(Enemy.mLocation.X, 10.0)
    Near(Enemy.mLocation.Y, 21.0)
    Near(Enemy.mLocation.Z, 0.0)
    Near(Enemy.mRotation.Yaw, 33.0)
    Near(Camera.mLocation.Z, 1.4)
    Near(Camera.mRotation.Pitch, 23.0)
    Near(Camera.mFieldOfView, 72.0)
    assert(Runtime.mStopped == 1 and not JumpScare.IsBlackout())
end)

Test("game over without a killer and successful escape skip the scare", function()
    GameManager.GameOver("OtherFailure")
    assert(GameManager.Phase == GameManager.EPhase.GameOver and Runtime.mPlayed == 0)
    GameManager.StartGame()
    GameManager.Escape("Car")
    assert(GameManager.Phase == GameManager.EPhase.Escaped and Runtime.mPlayed == 0)
end)

Test("missing view falls back to immediate game over", function(Player, View, Enemy)
    JumpScare.UnregisterView(View)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    assert(GameManager.Phase == GameManager.EPhase.GameOver and Runtime.mPlayed == 0)
end)

Test("unregistering a killer safely finishes an interrupted scare", function(Player, View, Enemy)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    GameManager.UnregisterEnemy(Enemy)
    GameManager.Tick(0.1)
    assert(GameManager.Phase == GameManager.EPhase.GameOver and Runtime.mStopped == 1)
    Near(Enemy.mLocation.Y, 21.0)
end)

Test("negative delta time cannot rewind the lunge and long frames finish safely", function(Player, View, Enemy)
    GameManager.GameOver("CaughtByEnemy", Enemy)
    GameManager.Tick(0.16)
    local Location = Enemy:GetActorLocation()
    GameManager.Tick(-1.0)
    Near(Enemy.mLocation.Y, Location.Y)
    GameManager.Tick(10.0)
    assert(GameManager.Phase == GameManager.EPhase.GameOver and JumpScare.IsBlackout())
end)

GameManager.Reset()
print("Jump scare tests passed: " .. Runtime.mPassed)
