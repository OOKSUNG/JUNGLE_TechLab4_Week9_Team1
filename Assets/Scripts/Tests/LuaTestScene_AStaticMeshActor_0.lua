local moveSpeed = 50.0
local elapsedTime = 0.0
local logTimer = 0.0
local startLocation = nil
local passedCount = 0
local failedCount = 0

local function NearlyEqual(a, b, tolerance)
    tolerance = tolerance or 0.0001
    return math.abs(a - b) <= tolerance
end

local function Check(name, condition)
    if condition then
        passedCount = passedCount + 1
        print("[BindingTest][PASS]", name)
    else
        failedCount = failedCount + 1
        print("[BindingTest][FAIL]", name)
    end
end

local function PrintVector(label, value)
    print(label, value.X, value.Y, value.Z)
end

local function InitializeRuntimeState()
    elapsedTime = 0.0
    logTimer = 0.0
    startLocation = self:GetActorLocation()
end

local function RunBindingChecks()
    passedCount = 0
    failedCount = 0

    Check("self exists", self ~= nil)
    Check("actor name exists", self:GetName() ~= nil and self:GetName() ~= "")
    Check("scriptPath exists", scriptPath ~= nil and scriptPath ~= "")
    Check("sceneName exists", sceneName ~= nil and sceneName ~= "")

    local a = FVector.new(1.0, 2.0, 3.0)
    local b = FVector.new(4.0, 5.0, 6.0)

    Check("FVector constructor/fields",
        a.X == 1.0 and a.Y == 2.0 and a.Z == 3.0)

    local sum = a + b
    Check("FVector addition",
        sum.X == 5.0 and sum.Y == 7.0 and sum.Z == 9.0)

    local difference = b - a
    Check("FVector subtraction",
        difference.X == 3.0 and difference.Y == 3.0 and difference.Z == 3.0)

    local scaled = a * 2.0
    Check("FVector multiplication",
        scaled.X == 2.0 and scaled.Y == 4.0 and scaled.Z == 6.0)

    Check("FVector SizeSquared", NearlyEqual(a:SizeSquared(), 14.0))
    Check("FVector Dot", NearlyEqual(a:Dot(b), 32.0))

    local cross = a:Cross(b)
    Check("FVector Cross",
        cross.X == -3.0 and cross.Y == 6.0 and cross.Z == -3.0)

    Check("FVector Distance", NearlyEqual(a:Distance(b), math.sqrt(27.0)))

    local rotation = FRotator.new(10.0, 20.0, 30.0)
    Check("FRotator constructor/fields",
        rotation.Pitch == 10.0 and rotation.Yaw == 20.0 and rotation.Roll == 30.0)

    local location = self:GetActorLocation()
    local actorRotation = self:GetActorRotation()
    local actorScale = self:GetActorScale3D()

    Check("AActor GetActorLocation", location ~= nil)
    Check("AActor GetActorRotation", actorRotation ~= nil)
    Check("AActor GetActorScale3D", actorScale ~= nil)
    Check("AActor SetActorLocation", self:SetActorLocation(location))
    Check("AActor SetActorRotation", self:SetActorRotation(actorRotation))
    Check("AActor SetActorScale3D", self:SetActorScale3D(actorScale))

    print("[BindingTest] result", passedCount, "passed", failedCount, "failed")
end

function BeginPlay()
    print("[BindingTest] BeginPlay")
    print("[BindingTest] actor", self:GetName())
    print("[BindingTest] scene", sceneName)
    print("[BindingTest] script", scriptPath)

    InitializeRuntimeState()
    PrintVector("[BindingTest] start location", startLocation)
    RunBindingChecks()
end

function Tick(deltaTime)
    elapsedTime = elapsedTime + deltaTime
    logTimer = logTimer + deltaTime

    local location = self:GetActorLocation()
    location.X = location.X + moveSpeed * deltaTime

    if not self:SetActorLocation(location) then
        print("[BindingTest][FAIL] Tick SetActorLocation")
        return
    end

    if logTimer >= 1.0 then
        logTimer = logTimer - 1.0
        print("[BindingTest] Tick", elapsedTime, "seconds")
        PrintVector("[BindingTest] current location", location)
    end
end

function OnOverlap(otherActor)
    if otherActor == nil then
        print("[BindingTest][FAIL] OnOverlap received nil")
        return
    end

    print("[BindingTest] OnOverlap with", otherActor:GetName())
end

function OnReload()
    print("[BindingTest] OnReload")
    InitializeRuntimeState()
    RunBindingChecks()
end

function EndPlay()
    print("[BindingTest] EndPlay after", elapsedTime, "seconds")
end