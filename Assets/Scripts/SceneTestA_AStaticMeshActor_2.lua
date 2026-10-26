local transitionCoroutine = nil

function BeginPlay()
    Log("[SceneTestA] BeginPlay")

    -- B 씬에서 RestartScene을 한 번만 실행하기 위한 테스트 값
    _G.SceneRestartTestDone = false

    transitionCoroutine = coroutine.create(function()
        Log("[SceneTestA] 2초 후 B 씬 로드")
        Wait(2.0)

        Log("[SceneTestA] LoadScene 요청")
        LoadScene("Assets/Scenes/Tests/SceneTestBBBAAA.scene")
    end)

    RegisterCoroutine(transitionCoroutine)
    StartCoroutine(transitionCoroutine)
end

function EndPlay()
    Log("[SceneTestA] EndPlay")
end