local GameManager = {}

GameManager.EPhase = {
    Ready = "Ready",
    Playing = "Playing",
    GameOver = "GameOver",
    Escaped = "Escaped",
}

local function ResetProgress()
    GameManager.Phase = GameManager.EPhase.Ready
    GameManager.ElapsedTime = 0.0
    GameManager.bLightOn = false
    GameManager.BatteriesUsed = 0
    GameManager.Route = nil
    GameManager.GameOverReason = nil
end

local function ClearReferences()
    GameManager.Player = nil
    GameManager.Enemies = {}
    GameManager.Items = {}
    GameManager.Map = nil
end

local function IndexOf(list, value)
    for index, element in ipairs(list) do
        if element == value then
            return index
        end
    end
    return nil
end

function GameManager.Reset()
    ResetProgress()
    ClearReferences()
end

function GameManager.StartGame()
    ResetProgress()
    GameManager.Phase = GameManager.EPhase.Playing
    print("[GameManager] StartGame")
end

function GameManager.Tick(dt)
    if GameManager.Phase == GameManager.EPhase.Playing then
        GameManager.ElapsedTime = GameManager.ElapsedTime + dt
    end
end

function GameManager.IsPlaying()
    return GameManager.Phase == GameManager.EPhase.Playing
end

function GameManager.RegisterPlayer(actor)
    if GameManager.Player and GameManager.Player ~= actor then
        print("[GameManager] Player replaced:", GameManager.Player:GetName(), "->", actor:GetName())
    end
    GameManager.Player = actor
end

function GameManager.UnregisterPlayer(actor)
    if GameManager.Player == actor then
        GameManager.Player = nil
    end
end

function GameManager.GetPlayer()
    return GameManager.Player
end

function GameManager.GetPlayerLocation()
    if not GameManager.Player then
        return nil
    end
    return GameManager.Player:GetActorLocation()
end

function GameManager.RegisterEnemy(actor)
    if IndexOf(GameManager.Enemies, actor) then
        return
    end
    table.insert(GameManager.Enemies, actor)
end

function GameManager.UnregisterEnemy(actor)
    local index = IndexOf(GameManager.Enemies, actor)
    if index then
        table.remove(GameManager.Enemies, index)
    end
end

function GameManager.GetEnemies()
    return GameManager.Enemies
end

function GameManager.IsEnemy(actor)
    return actor ~= nil and IndexOf(GameManager.Enemies, actor) ~= nil
end

function GameManager.RegisterItem(actor, itemId)
    for _, entry in ipairs(GameManager.Items) do
        if entry.Actor == actor then
            entry.ItemId = itemId
            return
        end
    end
    table.insert(GameManager.Items, { Actor = actor, ItemId = itemId })
end

function GameManager.UnregisterItem(actor)
    for index, entry in ipairs(GameManager.Items) do
        if entry.Actor == actor then
            table.remove(GameManager.Items, index)
            return
        end
    end
end

function GameManager.GetItems()
    return GameManager.Items
end

function GameManager.FindNearestItem(location, radius)
    local nearest = nil
    local nearestDistanceSquared = nil
    local radiusSquared = radius * radius
    for _, entry in ipairs(GameManager.Items) do
        local itemLocation = entry.Actor:GetActorLocation()
        local dx = itemLocation.X - location.X
        local dy = itemLocation.Y - location.Y
        local distanceSquared = dx * dx + dy * dy
        if distanceSquared <= radiusSquared and (nearest == nil or distanceSquared < nearestDistanceSquared) then
            nearest = entry
            nearestDistanceSquared = distanceSquared
        end
    end
    return nearest
end

function GameManager.SetMap(map)
    GameManager.Map = map
end

function GameManager.GetMap()
    return GameManager.Map
end

function GameManager.SetLightOn(bOn)
    GameManager.bLightOn = bOn and true or false
end

function GameManager.IsLightOn()
    return GameManager.bLightOn
end

function GameManager.AddBatteryUsed()
    GameManager.BatteriesUsed = GameManager.BatteriesUsed + 1
end

function GameManager.GameOver(reason)
    if not GameManager.IsPlaying() then
        return
    end
    GameManager.Phase = GameManager.EPhase.GameOver
    GameManager.GameOverReason = reason
    print("[GameManager] GameOver:", reason)
end

function GameManager.Escape(route)
    if not GameManager.IsPlaying() then
        return
    end
    GameManager.Phase = GameManager.EPhase.Escaped
    GameManager.Route = route
    print("[GameManager] Escaped:", route)
end

function GameManager.GetResult()
    return {
        Phase = GameManager.Phase,
        ElapsedTime = GameManager.ElapsedTime,
        BatteriesUsed = GameManager.BatteriesUsed,
        Route = GameManager.Route,
        GameOverReason = GameManager.GameOverReason,
    }
end

GameManager.Reset()

return GameManager
