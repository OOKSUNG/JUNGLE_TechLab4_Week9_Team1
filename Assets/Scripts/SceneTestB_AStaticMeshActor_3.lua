local restartCoroutine = nil

function BeginPlay()
    Log("[SceneTestB] BeginPlay")

    -- 재시작 후에는 다시 재시작하지 않도록 한다.
    if _G.SceneRestartTestDone then
        Log("[SceneTestB] Restart 완료")
        return
    end

    _G.SceneRestartTestDone = true

    restartCoroutine = coroutine.create(function()
        Log("[SceneTestB] 2초 후 현재 씬 재시작")
        Wait(2.0)

        Log("[SceneTestB] RestartScene 요청")
        RestartScene()
    end)

    RegisterCoroutine(restartCoroutine)
    StartCoroutine(restartCoroutine)
end

function EndPlay()
    Log("[SceneTestB] EndPlay")
end