local SlowMotionRemaining = 0.0
local LogElapsed = 0.0

local HitStopDebugRemaining = 0.0
local HitStopLogElapsed = 0.0

local function PrintTimeState(Label, DeltaTime)
    local RealDt = GetUnscaledDeltaTime()
    local WorldDt = GetWorldDeltaTime()

    print(string.format(
        "[TimeTest][%s] TickDt=%.6f RealDt=%.6f WorldDt=%.6f Global=%.3f Effective=%.3f RealTime=%.3f WorldTime=%.3f",
        Label,
        DeltaTime,
        RealDt,
        WorldDt,
        GetGlobalTimeDilation(),
        GetEffectiveTimeDilation(),
        GetRealTimeSeconds(),
        GetWorldTimeSeconds()
    ))
end

local function StartSlowMotion(Scale, RealDuration)
    SetGlobalTimeDilation(Scale)
    SlowMotionRemaining = RealDuration

    print(string.format(
        "[TimeTest] Slow motion started: Scale=%.2f Duration=%.2f real seconds",
        Scale,
        RealDuration
    ))
end

local function StopSlowMotion()
    SetGlobalTimeDilation(1.0)
    SlowMotionRemaining = 0.0

    print("[TimeTest] Time dilation restored to 1.0")
end

local function StartHitStop(Duration, Scale)
    HitStop(Duration, Scale)

    -- Hit Stop 도중 값을 자세히 출력하기 위한 디버그 시간
    HitStopDebugRemaining = Duration + 0.2
    HitStopLogElapsed = 0.0

    print(string.format(
        "[TimeTest] Hit Stop requested: Scale=%.2f Duration=%.2f real seconds",
        Scale,
        Duration
    ))
end

function BeginPlay()
    ResetTimeEffects()

    SlowMotionRemaining = 0.0
    LogElapsed = 0.0
    HitStopDebugRemaining = 0.0
    HitStopLogElapsed = 0.0

    print("[TimeTest] =================================")
    print("[TimeTest] F1: 3초 동안 0.2배 슬로모")
    print("[TimeTest] F2: 시간 배율 1.0으로 복구")
    print("[TimeTest] F3: 0.25초 완전 Hit Stop")
    print("[TimeTest] F4: 0.25초 동안 0.05배 Hit Stop")
    print("[TimeTest] =================================")
end

function Tick(DeltaTime)
    local RealDt = GetUnscaledDeltaTime()
    local EffectStartedThisFrame = false

    if IsKeyPressed(Key.F1) then
        StartSlowMotion(0.2, 3.0)
        EffectStartedThisFrame = true
    end

    if IsKeyPressed(Key.F2) then
        StopSlowMotion()
        EffectStartedThisFrame = true
    end

    if IsKeyPressed(Key.F3) then
        StartHitStop(0.25, 0.0)
        EffectStartedThisFrame = true
    end

    if IsKeyPressed(Key.F4) then
        StartHitStop(0.25, 0.05)
        EffectStartedThisFrame = true
    end

    -- 슬로모 지속시간은 WorldDt가 아니라 실제 시간으로 계산한다.
    if not EffectStartedThisFrame
        and SlowMotionRemaining > 0.0 then

        SlowMotionRemaining =
            SlowMotionRemaining - RealDt

        if SlowMotionRemaining <= 0.0 then
            StopSlowMotion()
        end
    end

    -- 평상시에는 0.5 실제 초마다 시간 상태를 출력한다.
    LogElapsed = LogElapsed + RealDt

    if LogElapsed >= 0.5 then
        LogElapsed = LogElapsed - 0.5
        PrintTimeState("Periodic", DeltaTime)
    end

    -- Hit Stop 요청 후에는 0.05 실제 초마다 자세히 출력한다.
    if HitStopDebugRemaining > 0.0 then
        HitStopDebugRemaining =
            HitStopDebugRemaining - RealDt

        HitStopLogElapsed =
            HitStopLogElapsed + RealDt

        if HitStopLogElapsed >= 0.05 then
            HitStopLogElapsed =
                HitStopLogElapsed - 0.05

            PrintTimeState("HitStop", DeltaTime)
        end
    end
end

function EndPlay()
    ResetTimeEffects()
    print("[TimeTest] EndPlay: time effects reset")
end

function OnReload()
    ResetTimeEffects()

    SlowMotionRemaining = 0.0
    LogElapsed = 0.0
    HitStopDebugRemaining = 0.0
    HitStopLogElapsed = 0.0

    print("[TimeTest] Reloaded: time effects reset")
end