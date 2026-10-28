local IntroCutscene = require("IntroCutscene")
local GameManager = require("GameManager")

function BeginPlay()
    IntroCutscene.RegisterView(self)
end

function Tick(DeltaTime)
    if GameManager.Phase ~= GameManager.EPhase.Intro then
        return
    end
    local State = IntroCutscene.GetState()
    if State ~= nil and State.mElapsed >= 0.5 and (IsKeyPressed(Key.Space) or IsKeyPressed(Key.Enter)) then
        IntroCutscene.Finish()
    end
    local Viewport = GetViewportSize()
    if Viewport.X <= 0 or Viewport.Y <= 0 then
        return
    end
    local Time = State ~= nil and State.mElapsed or 0.0
    local Scale = math.max(0.5, math.min(1.5, math.min(Viewport.X / 1280, Viewport.Y / 720)))
    local Bars = Viewport.Y * 0.08 * (1.0 - math.max(0.0, math.min(1.0, (Time - 8.8) / 1.2)))
    AddUIImage("Assets/UI/Title/Black.png", FVector2.new(Viewport.X, Bars), FVector2.new(0, 0), FVector2.new(0, 0), FVector2.new(0, 0))
    AddUIImage("Assets/UI/Title/Black.png", FVector2.new(Viewport.X, Bars), FVector2.new(0, 1), FVector2.new(0, 1), FVector2.new(0, 0))
    if Time >= 2.0 and Time < 5.8 then
        AddUIText("시설 진입", 28 * Scale, FVector2.new(0.07, 0.15), FVector2.new(0, 0), FVector2.new(0, 0))
    end
    AddUIText("[Space / Enter] 건너뛰기", 16 * Scale, FVector2.new(0.98, 0.98), FVector2.new(1, 1), FVector2.new(0, 0))
end

function EndPlay()
    IntroCutscene.ReleaseActor(self)
end
