local GameManager = require("GameManager")

local FOOTSTEP_SOUND = "Assets/Sounds/발소리2.mp3"
local MAX_VOLUME = 0.5
local REFERENCE_SPEED = 3.0
local MIN_PITCH = 0.5
local MAX_PITCH = 1.4
local VOLUME_CHANGE_PER_SECOND = 6.0
local PITCH_CHANGE_PER_SECOND = 2.0
local MOVING_SPEED_THRESHOLD = 0.2

local handle = 0
local volume = 0.0
local pitch = 1.0
local lastLocation = nil

local function MoveToward(current, target, step)
    if current < target then
        return math.min(target, current + step)
    end
    return math.max(target, current - step)
end

local function HorizontalSpeed(location, dt)
    if not lastLocation or dt <= 0.0 then
        return 0.0
    end
    local dx = location.X - lastLocation.X
    local dy = location.Y - lastLocation.Y
    return math.sqrt(dx * dx + dy * dy) / dt
end

function BeginPlay()
    volume = 0.0
    pitch = 1.0
    lastLocation = nil
    handle = PlaySound(FOOTSTEP_SOUND, true, 0.0)
    if handle == 0 then
        print("[PlayerFootsteps] Cannot play", FOOTSTEP_SOUND)
    end
end

function Tick(dt)
    if handle == 0 then
        return
    end

    local location = self:GetActorLocation()
    local speed = HorizontalSpeed(location, dt)
    local bMoving = speed > MOVING_SPEED_THRESHOLD
    lastLocation = { X = location.X, Y = location.Y }

    local target = (bMoving and GameManager.IsPlaying()) and MAX_VOLUME or 0.0
    local newVolume = MoveToward(volume, target, VOLUME_CHANGE_PER_SECOND * dt)
    if newVolume ~= volume then
        volume = newVolume
        SetSoundVolume(handle, volume)
    end

    if bMoving then
        local targetPitch = math.max(MIN_PITCH, math.min(MAX_PITCH, speed / REFERENCE_SPEED))
        local newPitch = MoveToward(pitch, targetPitch, PITCH_CHANGE_PER_SECOND * dt)
        if newPitch ~= pitch then
            pitch = newPitch
            SetSoundPitch(handle, pitch)
        end
    end
end

function EndPlay()
    if handle ~= 0 then
        StopSound(handle)
        handle = 0
    end
end
