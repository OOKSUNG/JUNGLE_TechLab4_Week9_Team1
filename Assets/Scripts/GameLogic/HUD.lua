local GameManager = require("GameManager")
local Flashlight = require("Flashlight")
local Inventory = require("Inventory")
local ItemData = require("ItemData")
local Stamina = require("Stamina")

local SMALL = 30
local MEDIUM = 40
local LARGE = 90
local MARGIN = 20
local BATTERY_SIZE = FVector2.new(270, 90)
local STAMINA_FRAME_SIZE = FVector2.new(320, 64)
local STAMINA_FILL_SIZE = FVector2.new(292, 18)
local STAMINA_FILL_INSET = FVector2.new(14, 23)

local function V(x, y)
    return FVector2.new(x, y)
end

local function DrawTime()
    AddUIText(string.format("시간 %.1f", GameManager.ElapsedTime), MEDIUM, V(1, 0), V(1, 0), V(-MARGIN, MARGIN))
end

local function DrawBattery()
    AddUIImage("Assets/UI/BatteryFill.png", BATTERY_SIZE, V(1, 1), V(1, 1), V(-MARGIN, -MARGIN), Flashlight.GetBatteryRatio())
    AddUIImage("Assets/UI/BatteryFrame.png", BATTERY_SIZE, V(1, 1), V(1, 1), V(-MARGIN, -MARGIN))

    local label = Flashlight.IsSwapping() and "배터리 교체 중..." or string.format("배터리 %d초", math.ceil(Flashlight.GetBattery()))
    AddUIText(label, SMALL, V(1, 1), V(1, 1), V(-MARGIN, -MARGIN - BATTERY_SIZE.Y - 10))
end

local function DrawStamina()
    AddUIImage("Assets/UI/StaminaFrame.png", STAMINA_FRAME_SIZE,
        V(0, 1), V(0, 1), V(MARGIN, -MARGIN))
    -- 충전 영역만 실제 스태미나 비율로 잘라 프레임 안에 표시한다.
    AddUIImage("Assets/UI/StaminaFill.png", STAMINA_FILL_SIZE,
        V(0, 1), V(0, 1), V(MARGIN + STAMINA_FILL_INSET.X, -MARGIN - STAMINA_FILL_INSET.Y),
        Stamina.GetRatio())
end

local function DrawPickupPrompt()
    if Inventory.IsOpen() then
        return
    end
    local location = GameManager.GetPlayerLocation()
    if not location then
        return
    end
    local entry = GameManager.FindNearestItem(location, Inventory.Config.PickupRadius)
    if not entry then
        return
    end
    local item = ItemData.Get(entry.ItemId)
    local name = item and item.Name or entry.ItemId
    AddUIText("[E] 줍기: " .. name, MEDIUM, V(0.5, 1), V(0.5, 1), V(0, -120))
end

local function DrawInventory()
    if not Inventory.IsOpen() then
        return
    end

    local lineHeight = SMALL * 1.4
    local y = 0
    local function Line(text)
        AddUIText(text, SMALL, V(0, 0.3), V(0, 0), V(MARGIN * 2, y))
        y = y + lineHeight
    end

    Line(string.format("가방   무게 %.1f   속도 %d%%", Inventory.GetTotalWeight(), math.floor(Inventory.GetSpeedMultiplier() * 100 + 0.5)))
    y = y + lineHeight * 0.3

    local slots = Inventory.GetSlots()
    if #slots == 0 then
        Line("  (비어 있음)")
    end
    for index, slot in ipairs(slots) do
        local marker = index == Inventory.GetSelectedIndex() and "> " or "   "
        local usable = slot.bUsable and "" or "   (사용 불가)"
        Line(string.format("%s%s x%d%s", marker, slot.Name, slot.Count, usable))
    end

    y = y + lineHeight * 0.3
    Line("[Up/Down] 선택   [Enter] 사용   [Tab] 닫기")
end

local function DrawResult()
    local phase = GameManager.Phase
    if phase ~= GameManager.EPhase.GameOver and phase ~= GameManager.EPhase.Escaped then
        return
    end

    local result = GameManager.GetResult()
    local title = phase == GameManager.EPhase.GameOver and "게임 오버" or ("탈출 성공 - 루트 " .. tostring(result.Route))
    AddUIText(title, LARGE, V(0.5, 0.5), V(0.5, 1), V(0, -20))
    AddUIText(string.format("시간 %.1f초   사용한 배터리 %d개", result.ElapsedTime, result.BatteriesUsed), MEDIUM, V(0.5, 0.5), V(0.5, 0), V(0, 20))
    AddUIText("[R] 재시작", MEDIUM, V(0.5, 0.5), V(0.5, 0), V(0, 80))
end

function Tick(dt)
    if GameManager.IsPlaying() then
        DrawTime()
        DrawBattery()
        DrawStamina()
        DrawPickupPrompt()
        DrawInventory()
    end
    DrawResult()
end
