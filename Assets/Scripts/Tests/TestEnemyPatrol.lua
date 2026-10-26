local GameManager = require("GameManager")

local SPEED = 4.0
local PATROL_DISTANCE = 36.0

local startLocation = nil
local offset = 0.0
local direction = 1.0

function BeginPlay()
    local location = self:GetActorLocation()
    startLocation = { X = location.X, Y = location.Y, Z = location.Z }
    offset = 0.0
    direction = 1.0
    GameManager.RegisterEnemy(self)
end

function Tick(dt)
    if not startLocation then
        return
    end

    offset = offset + direction * SPEED * dt
    if offset >= PATROL_DISTANCE then
        offset = PATROL_DISTANCE
        direction = -1.0
    elseif offset <= 0.0 then
        offset = 0.0
        direction = 1.0
    end

    self:SetActorLocation(FVector.new(startLocation.X, startLocation.Y + offset, startLocation.Z))
end

function EndPlay()
    GameManager.UnregisterEnemy(self)
end
