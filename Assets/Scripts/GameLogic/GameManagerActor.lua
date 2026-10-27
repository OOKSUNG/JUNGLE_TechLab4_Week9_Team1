local GameManager = require("GameManager")
local EndingCutscene = require("EndingCutscene")
local Runtime = { mEndingRequested = false }

function BeginPlay()
    Runtime.mEndingRequested = false
    EndingCutscene.SetGameScene("Assets/Scenes/" .. sceneName .. ".scene")
    GameManager.StartGame()
end

function Tick(DeltaTime)
    local Phase = GameManager.Phase
    if Phase == GameManager.EPhase.Ending then
        if not Runtime.mEndingRequested then
            Runtime.mEndingRequested = true
            LoadScene(EndingCutscene.GetPendingScene())
        end
        return
    end
    if (Phase == GameManager.EPhase.GameOver or Phase == GameManager.EPhase.Escaped) and IsKeyPressed(Key.R) then
        RestartScene()
        return
    end

    GameManager.Tick(DeltaTime)
end

function EndPlay()
    GameManager.Reset()
end
