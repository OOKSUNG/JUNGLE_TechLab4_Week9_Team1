local SOUND_PATH = "Assets/Sounds/Test.wav"

local handle = 0
local elapsed = 0.0
local phase = 0

function BeginPlay()
    elapsed = 0.0
    phase = 0
    handle = PlaySound(SOUND_PATH, true, 0.0)
    print("[AudioTest] PlaySound handle", handle)

    if handle == 0 then
        print("[AudioTest][FAIL] PlaySound returned 0")
        return
    end

    FadeSound(handle, 1.0, 2.0)
    phase = 1
end

function Tick(dt)
    if handle == 0 then
        return
    end

    elapsed = elapsed + dt

    if phase == 1 and elapsed >= 3.0 then
        FadeSound(handle, 0.0, 2.0)
        print("[AudioTest] fade out")
        phase = 2
    elseif phase == 2 and elapsed >= 5.5 then
        StopSound(handle)
        print("[AudioTest] stopped, playing =", IsSoundPlaying(handle))

        local oneShot = PlaySound(SOUND_PATH, false, 0.5)
        print("[AudioTest] one-shot handle", oneShot)
        phase = 3
    end
end

function EndPlay()
    print("[AudioTest] EndPlay")
end
