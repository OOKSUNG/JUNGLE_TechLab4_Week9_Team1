local EndingCutscene = require("EndingCutscene")

function BeginPlay()
    EndingCutscene.RegisterGate(self)
end

function EndPlay()
    EndingCutscene.UnregisterGate(self)
end
