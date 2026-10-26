local GameManager = require("GameManager")

function BeginPlay()
    GameManager.StartGame()
end

function Tick(dt)
    GameManager.Tick(dt)
end

function EndPlay()
    GameManager.Reset()
end
