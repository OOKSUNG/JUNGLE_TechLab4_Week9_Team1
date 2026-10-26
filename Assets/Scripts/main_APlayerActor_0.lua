local Inventory = require("Inventory")
local Stamina = require("Stamina")
local WalkingCamera = require("WalkingCamera")

local MouseSensitivityX = 0.12
local MouseSensitivityY = 0.12
local WalkSpeed = 3.0
local RunSpeed = 5.0
local DefaultHeadBobStrength = 1.0
local WalkingStateKey = sceneName .. ":" .. self:GetName()
local Runtime = { mHeadBobStrength = DefaultHeadBobStrength }

local function Initialize()
    local Rotation = self:GetActorRotation()
    Runtime.mHeadBobStrength = WalkingCamera.Start(WalkingStateKey, self, Rotation.Pitch, DefaultHeadBobStrength)
    self:SetActorRotation(FRotator.new(0.0, Rotation.Yaw, 0.0))
end

function BeginPlay()
    print("BeginPlay!\n")
    Stamina.Reset()
    Initialize()
    Log("[PlayerCamera] F6: head bob off/subtle, [: narrower view, ]: wider view")
end

function EndPlay()
    WalkingCamera.Stop(WalkingStateKey)
end

function OnOverlap(OtherActor)
end

-- Shape의 BeginOverlap은 기존 OnOverlap으로 전달됩니다.
function OnEndOverlap(OtherActor)
end

-- Hit는 Sweep 이동으로 발생하며 Hit 정보는 Lua에 복사되어 전달됩니다.
function OnHit(OtherActor, Hit)

end

function Tick(DeltaTime)
    if DeltaTime <= 0.0 then
        return
    end

    if IsKeyPressed(Key.F6) then
        Runtime.mHeadBobStrength = Runtime.mHeadBobStrength > 0.0 and 0.0 or 1.0
        WalkingCamera.SetHeadBobStrength(WalkingStateKey, Runtime.mHeadBobStrength)
        Log("[PlayerCamera] Head bob:", Runtime.mHeadBobStrength > 0.0 and "Subtle (6 mm maximum)" or "Off")
    end

    local FieldOfViewDelta = 0.0
    if IsKeyPressed(Key.LeftBracket) then
        FieldOfViewDelta = FieldOfViewDelta - 2.0
    end
    if IsKeyPressed(Key.RightBracket) then
        FieldOfViewDelta = FieldOfViewDelta + 2.0
    end
    if FieldOfViewDelta ~= 0.0 then
        local FieldOfView = WalkingCamera.AdjustFieldOfView(WalkingStateKey, FieldOfViewDelta)
        if FieldOfView ~= nil then
            Log("[PlayerCamera] Vertical field of view:", FieldOfView)
        end
    end

    if IsMouseDown(MouseButton.Right) then
        local MouseDeltaX = GetMouseDeltaX()
        local MouseDeltaY = GetMouseDeltaY()

        if MouseDeltaX ~= 0 or MouseDeltaY ~= 0 then
            local Rotation = self:GetActorRotation()
            Rotation.Yaw = (Rotation.Yaw + MouseDeltaX * MouseSensitivityX + 180) % 360 - 180
            self:SetActorRotation(Rotation)
            WalkingCamera.Look(WalkingStateKey, MouseDeltaY * MouseSensitivityY)
        end
    end

    local Direction = FVector.new(0, 0, 0)

    if IsKeyDown(Key.W) then
        Direction.X = Direction.X + 1
    end
    if IsKeyDown(Key.S) then
        Direction.X = Direction.X - 1
    end
    if IsKeyDown(Key.D) then
        Direction.Y = Direction.Y + 1
    end
    if IsKeyDown(Key.A) then
        Direction.Y = Direction.Y - 1
    end

    local IsMoving = Direction:SizeSquared() > 0.0
    local IsRunning = Stamina.Tick(DeltaTime, IsKeyDown(Key.Shift), IsMoving)
    local Speed = (IsRunning and RunSpeed or WalkSpeed) * Inventory.GetSpeedMultiplier()
    local Rotation = self:GetActorRotation()
    local YawRadians = math.rad(Rotation.Yaw)
    local CosYaw = math.cos(YawRadians)
    local SinYaw = math.sin(YawRadians)
    local Movement = FVector.new(0, 0, 0)

    if IsMoving then
        local LocalDirection = Direction:Normalized()
        local WorldDirection = FVector.new(LocalDirection.X * CosYaw - LocalDirection.Y * SinYaw, LocalDirection.X * SinYaw + LocalDirection.Y * CosYaw, 0.0)
        local Delta = WorldDirection * Speed * DeltaTime
        local PreviousLocation = self:GetActorLocation()
        self:Move(FVector.new(Delta.X, 0, 0), Rotation)
        self:Move(FVector.new(0, Delta.Y, 0), Rotation)
        Movement = self:GetActorLocation() - PreviousLocation
    end

    local LocalMovement = FVector.new(Movement.X * CosYaw + Movement.Y * SinYaw, -Movement.X * SinYaw + Movement.Y * CosYaw, 0.0)
    WalkingCamera.Update(WalkingStateKey, LocalMovement, Speed, DeltaTime)
end



function OnReload()
    Initialize()
end
