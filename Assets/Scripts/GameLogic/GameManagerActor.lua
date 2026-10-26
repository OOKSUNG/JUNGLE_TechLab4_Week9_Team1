local GameManager = require("GameManager")

function BeginPlay()
    GameManager.StartGame()
end

function Tick(dt)
    local phase = GameManager.Phase
    if (phase == GameManager.EPhase.GameOver or phase == GameManager.EPhase.Escaped)
        and IsKeyPressed(Key.R) then
        RestartScene()
        return
    end

    GameManager.Tick(dt)
end

function EndPlay()
    GameManager.Reset()
end
