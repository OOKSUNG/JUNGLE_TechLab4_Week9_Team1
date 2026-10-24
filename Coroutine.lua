function Wait(seconds)
    coroutine.yield("wait", seconds)
end

function WaitUntil(condition)
    coroutine.yield("wait_until", condition)
end

function Attack()
    print("coroutine started")
    Wait(6)
    print("coroutine ended")
end

local co = coroutine.create(Attack); 
RegisterCoroutine(co);
StartCoroutine(co);


