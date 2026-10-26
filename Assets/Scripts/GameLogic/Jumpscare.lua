local GameManager = require("GameManager")

local ROOT_NAME = "JumpscareRoot"
local MESH_NAME = "JumpscareMonster"
local TRIGGER_REASON = "CaughtByEnemy"

local SCREAM_SOUND = "Assets/Sounds/울음소리.mp3"
local SCREAM_VOLUME = 1.0
local SCREAM_PITCH = 0.85

local DARK_TIME = 0.35
local LUNGE_TIME = 0.22
local HOLD_TIME = 0.9

local START_DISTANCE = 3.2
local END_DISTANCE = 0.75
local SIDE_OFFSET = 0.0
local HEIGHT_OFFSET = 0.0
local BASE_YAW = 180.0

local MESH_PIVOT_OFFSET = FVector.new(-0.057, -0.273, -1.402)

local FLASH_INTENSITY = 1.0  
local FLICKER_MIN = 0.3      
local FLICKER_OFF_CHANCE = 0.15
local FLICKER_INTERVAL = 0.05
local SHAKE_OFFSET = 0.02
local SHAKE_ANGLE = 3.0

local EState = {
    Idle = "Idle",
    Dark = "Dark",
    Lunge = "Lunge",
    Hold = "Hold",
    Done = "Done",
}

local state = EState.Idle
local elapsed = 0.0
local flickerTimer = 0.0
local root = nil
local mesh = nil
local light = nil
local screamHandle = nil

local function Jitter(amount)
    return (math.random() * 2.0 - 1.0) * amount
end

local function PlaceMonster(distance, shake)
    root:SetRelativeLocation(FVector.new(
        distance,
        SIDE_OFFSET + Jitter(shake),
        HEIGHT_OFFSET + Jitter(shake)))
    local angle = shake > 0.0 and SHAKE_ANGLE or 0.0
    root:SetRelativeRotation(FRotator.new(Jitter(angle), BASE_YAW + Jitter(angle), Jitter(angle)))
end

local function SetLight(bOn, intensity)
    if not light then
        return
    end
    light:SetVisibility(bOn)
    if intensity then
        light:SetIntensity(intensity)
    end
end

local function HideEnemies()
    for _, enemy in ipairs(GameManager.GetEnemies()) do
        enemy:SetVisible(false)
    end
end

local function Begin()
    state = EState.Dark
    elapsed = 0.0
    GameManager.SetJumpscarePlaying(true)
    HideEnemies()
    SetLight(false)
    mesh:SetVisible(false)
end

local function Reveal()
    state = EState.Lunge
    elapsed = 0.0
    PlaceMonster(START_DISTANCE, 0.0)
    mesh:SetVisible(true)
    SetLight(true, FLASH_INTENSITY)
    screamHandle = PlaySound(SCREAM_SOUND, false, SCREAM_VOLUME)
    if screamHandle ~= 0 then
        SetSoundPitch(screamHandle, SCREAM_PITCH)
    end
end

local function Finish()
    state = EState.Done
    mesh:SetVisible(false)
    SetLight(false)
    GameManager.SetJumpscarePlaying(false)
end

local function ShouldStart()
    return GameManager.Phase == GameManager.EPhase.GameOver
        and GameManager.GameOverReason == TRIGGER_REASON
end

function BeginPlay()
    state = EState.Idle
    root = self:GetComponent(ROOT_NAME)
    mesh = self:GetComponent(MESH_NAME)
    light = self:GetSpotLight()
    if not root or not mesh then
        print("[Jumpscare] Missing component", ROOT_NAME, MESH_NAME)
        return
    end
    mesh:SetRelativeLocation(MESH_PIVOT_OFFSET)
    mesh:SetVisible(false)
end

function Tick(dt)
    if not root or not mesh or dt <= 0.0 then
        return
    end

    if state == EState.Idle then
        if ShouldStart() then
            Begin()
        end
        return
    end

    elapsed = elapsed + dt

    if state == EState.Dark then
        if elapsed >= DARK_TIME then
            Reveal()
        end
    elseif state == EState.Lunge then
        local alpha = math.min(elapsed / LUNGE_TIME, 1.0)
        local eased = 1.0 - (1.0 - alpha) ^ 3
        PlaceMonster(START_DISTANCE + (END_DISTANCE - START_DISTANCE) * eased, SHAKE_OFFSET * eased)
        if alpha >= 1.0 then
            state = EState.Hold
            elapsed = 0.0
            flickerTimer = 0.0
        end
    elseif state == EState.Hold then
        PlaceMonster(END_DISTANCE, SHAKE_OFFSET)
        flickerTimer = flickerTimer - dt
        if flickerTimer <= 0.0 then
            flickerTimer = FLICKER_INTERVAL
            local bOff = math.random() < FLICKER_OFF_CHANCE
            SetLight(not bOff, FLICKER_MIN + math.random() * (FLASH_INTENSITY - FLICKER_MIN))
        end
        if elapsed >= HOLD_TIME then
            Finish()
        end
    end
end

function EndPlay()
    if state ~= EState.Idle and state ~= EState.Done then
        GameManager.SetJumpscarePlaying(false)
    end
    state = EState.Idle
    root = nil
    mesh = nil
    light = nil
    screamHandle = nil
end
