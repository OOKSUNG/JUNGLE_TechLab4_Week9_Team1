local MODE = "overlap"

local START_X, START_Y, START_Z = -3.0, 0.0, 0.0
local TRAVEL_DISTANCE = 6.0
local SPEED = 2.0
local HOLD_SECONDS = 1.0
local START_DELAY = 1.0
local CHECK_AFTER_SECONDS = 8.0
local LOG_TAG = "v1" -- Change to v2 and save to check Hot Reload.

local elapsed = 0.0
local reportTimer = 0.0
local beginCount, endCount, hitCount = 0, 0, 0
local completedOverlap = false
local sawBlockingHit = false
local checked = false
local movementFailed = false
local activeOverlaps = {}
local actorName = "?"

local function Report(event, ...)
    Log("[CollisionTest]", actorName, LOG_TAG, event, ...)
end

local function OtherName(otherActor)
    -- The other Actor may already have been destroyed by another callback.
    if otherActor == nil then
        return "<destroyed-or-missing>"
    end
    return otherActor:GetName()
end

local function Initialize(reason)
    elapsed, reportTimer = 0.0, 0.0
    beginCount, endCount, hitCount = 0, 0, 0
    completedOverlap, sawBlockingHit = false, false
    checked, movementFailed = false, false
    activeOverlaps = {}
    actorName = self:GetName()

    Report(reason, "mode=", MODE, "scene=", sceneName, "file=", scriptPath)
    if MODE == "overlap" then
        -- A fixed start makes reloading reproducible, even during movement.
        movementFailed = not self:SetActorLocation(FVector.new(START_X, START_Y, START_Z))
        Report("SETUP", "Lua movement: X=-3 -> X=3 -> X=-3; target at (0,0,0)")
    elseif MODE == "hit" then
        Report("SETUP", "Lua movement disabled; use ProjectileMovement with Sweep")
    elseif MODE == "observer" then
        Report("SETUP", "Lua movement disabled; waiting for events")
    else
        Report("[FAIL]", "Unknown MODE; choose overlap, hit, or observer")
        movementFailed = true
    end

    if movementFailed and MODE == "overlap" then
        Report("[FAIL]", "SetActorLocation failed; check the root component")
    end
end

function BeginPlay()
    Initialize("BEGIN_PLAY")
end

function Tick(dt)
    elapsed = elapsed + dt
    reportTimer = reportTimer + dt

    if MODE == "overlap" and not movementFailed and elapsed >= START_DELAY then
        local travelSeconds = TRAVEL_DISTANCE / SPEED
        local cycleSeconds = 2.0 * (travelSeconds + HOLD_SECONDS)
        local phase = (elapsed - START_DELAY) % cycleSeconds
        local offset
        if phase < travelSeconds then
            offset = phase * SPEED
        elseif phase < travelSeconds + HOLD_SECONDS then
            offset = TRAVEL_DISTANCE
        elseif phase < 2.0 * travelSeconds + HOLD_SECONDS then
            offset = TRAVEL_DISTANCE - (phase - travelSeconds - HOLD_SECONDS) * SPEED
        else
            offset = 0.0
        end

        if not self:SetActorLocation(FVector.new(START_X + offset, START_Y, START_Z)) then
            movementFailed = true
            Report("[FAIL]", "Tick SetActorLocation failed")
        end
    end

    -- No per-frame logs: this heartbeat confirms Tick is running.
    if reportTimer >= 4.0 then
        reportTimer = reportTimer % 4.0
        Report("COUNTS", "begin=", beginCount, "end=", endCount, "hit=", hitCount)
    end

    if not checked and elapsed >= CHECK_AFTER_SECONDS then
        checked = true
        if MODE == "overlap" then
            if completedOverlap then
                Report("[PASS]", "Overlap Begin/End pair received")
            else
                Report("[FAIL]", "No complete Overlap pair; check both Shapes, flags, positions, and script files")
            end
        elseif MODE == "hit" then
            if sawBlockingHit then
                Report("[PASS]", "Blocking Hit received")
            else
                Report("[FAIL]", "No Hit; check Shape root, Block, ProjectileMovement, Sweep, and velocity")
            end
        end
    end
end

function OnOverlap(otherActor)
    beginCount = beginCount + 1
    local name = OtherName(otherActor)
    activeOverlaps[name] = true
    Report("OVERLAP_BEGIN", "count=", beginCount, "other=", name)
end

function OnEndOverlap(otherActor)
    endCount = endCount + 1
    local name = OtherName(otherActor)
    if activeOverlaps[name] then
        completedOverlap = true
        activeOverlaps[name] = nil
    end
    Report("OVERLAP_END", "count=", endCount, "other=", name)
end

function OnHit(otherActor, hit)
    hitCount = hitCount + 1
    if hit == nil then
        Report("[FAIL]", "OnHit received nil HitResult")
        return
    end

    sawBlockingHit = sawBlockingHit or hit.bBlockingHit
    -- A component pressing against a wall may emit Hit on successive moves.
    if hitCount <= 3 then
        Report("HIT", "count=", hitCount, "other=", OtherName(otherActor),
            "blocking=", hit.bBlockingHit,
            "point=", hit.ImpactPoint.X, hit.ImpactPoint.Y, hit.ImpactPoint.Z,
            "normal=", hit.Normal.X, hit.Normal.Y, hit.Normal.Z)
    elseif hitCount == 4 then
        Report("HIT", "Further Hit details suppressed; see COUNTS")
    end
end

function OnReload()
    Initialize("RELOADED")
end

function EndPlay()
    Report("END_PLAY", "begin=", beginCount, "end=", endCount, "hit=", hitCount)
end
