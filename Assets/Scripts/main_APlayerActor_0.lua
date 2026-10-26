local Inventory = require("Inventory")
local Stamina = require("Stamina")

local MouseSensitivity = 0.2
local WalkSpeed = 3.0
local RunSpeed = 5.0

function BeginPlay()
print("BeginPlay!\n")
    Stamina.Reset()
end

function EndPlay()

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
    if IsMouseDown(MouseButton.Right) then
        local MouseDeltaX = GetMouseDeltaX()
        local MouseDeltaY = GetMouseDeltaY()

        if MouseDeltaX ~= 0 or MouseDeltaY ~= 0 then
            local Rotation = self:GetActorRotation()
            Rotation.Yaw = (Rotation.Yaw + MouseDeltaX * MouseSensitivity + 180) % 360 - 180
            Rotation.Pitch = math.max(-89, math.min(89, Rotation.Pitch + MouseDeltaY * MouseSensitivity))
            self:SetActorRotation(Rotation)
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

    local bMoving = Direction:SizeSquared() > 0
    local bRunning = Stamina.Tick(DeltaTime, IsKeyDown(Key.Shift), bMoving)

    if bMoving then
        local Speed = (bRunning and RunSpeed or WalkSpeed) * Inventory.GetSpeedMultiplier()
        local Rotation = self:GetActorRotation()
        local YawRadians = math.rad(Rotation.Yaw)
        local CosYaw = math.cos(YawRadians)
        local SinYaw = math.sin(YawRadians)
        local WorldDirection = FVector.new(Direction.X * CosYaw - Direction.Y * SinYaw, Direction.X * SinYaw + Direction.Y * CosYaw, 0)
        local Delta = WorldDirection:Normalized() * Speed * DeltaTime
        self:Move(Delta, Rotation)
    end
end



function OnReload()

end
