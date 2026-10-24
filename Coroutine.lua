function Wait(seconds)
    coroutine.yield("wait", seconds)
end

function WaitUntil(condition)
    coroutine.yield("wait_until", condition)
end

function Attack()
    print("coroutine started")
    Wait(3)
    print("coroutine started2")
    Wait(5)
    print("coroutine started3")
    Wait(4)
    print("coroutine ended")
end

local co = coroutine.create(Attack); 
RegisterCoroutine(co);
StartCoroutine(co);


            