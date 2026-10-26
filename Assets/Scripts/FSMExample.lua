local FSM = require("FSM")
local States = require("FSMExampleStates")
local Runtime = { mMachine = nil }

local function Initialize()
    if Runtime.mMachine ~= nil then
        Runtime.mMachine:Stop()
    end

    local Location = self:GetActorLocation()
    local Data = { mOrigin = FVector.new(Location.X, Location.Y, Location.Z), mDirection = 1.0, mDestinationX = Location.X, mPatrolDistance = 3.0, mPatrolSpeed = 2.0, mIdleDuration = 1.0, mStunDuration = 1.5, mResumeState = "Idle" }
    Runtime.mMachine = FSM.New(self, States, Data)
    Runtime.mMachine:Start("Idle")
    Log("[FSMExample]", self:GetName(), "Space: stun for 1.5 seconds; patrol: origin X +/- 3")
end

function BeginPlay()
    Initialize()
end

function Tick(DeltaTime)
    if Runtime.mMachine == nil then
        return
    end

    if IsKeyPressed(Key.Space) then
        Runtime.mMachine:HandleEvent("Stun")
    end
    Runtime.mMachine:Tick(DeltaTime)
end

function OnOverlap(OtherActor)
    if Runtime.mMachine ~= nil then
        Runtime.mMachine:HandleEvent("OnOverlap", OtherActor)
    end
end

function OnEndOverlap(OtherActor)
    if Runtime.mMachine ~= nil then
        Runtime.mMachine:HandleEvent("OnEndOverlap", OtherActor)
    end
end

function OnHit(OtherActor, Hit)
    if Runtime.mMachine ~= nil then
        Runtime.mMachine:HandleEvent("OnHit", OtherActor, Hit)
    end
end

function EndPlay()
    if Runtime.mMachine ~= nil then
        Runtime.mMachine:Stop()
        Runtime.mMachine = nil
    end
end

function OnReload()
    Initialize()
end
