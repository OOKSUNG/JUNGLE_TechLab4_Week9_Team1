local EndingCutscene = require("EndingCutscene")

function BeginPlay()
    EndingCutscene.RegisterSubject(self)
end

function EndPlay()
    EndingCutscene.UnregisterSubject(self)
end
