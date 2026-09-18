-- Match UITweaks' movement-based zoom with cancellable, discrete eased steps.
local targetZoom
local animationID = 0

local function EaseZoom(desiredZoom)
    local startingZoom = Minimap:GetZoom()
    targetZoom = desiredZoom
    animationID = animationID + 1
    local currentAnimation = animationID
    local steps = math.abs(desiredZoom - startingZoom)
    local direction = desiredZoom > startingZoom and 1 or -1

    for step = 1, steps do
        local easedTime = math.acos(1 - 2 * step / steps) / math.pi
        local zoom = startingZoom + direction * step
        C_Timer.After(0.45 * easedTime, function()
            if animationID == currentAnimation then
                Minimap:SetZoom(zoom)
            end
        end)
    end
end

local function UpdateMinimapZoom()
    local maximum = math.max(0, Minimap:GetZoomLevels() - 1)
    local movingZoom = math.floor(maximum * 0.6 + 0.5)
    local desiredZoom = movingZoom

    -- Avoid inspecting movement values in combat; they can be secret in this client.
    if not InCombatLockdown() then
        local flying = IsFlying("player")
        if issecretvalue and issecretvalue(flying) then
            return
        end
        if flying then
            desiredZoom = 0
        else
            local speed = GetUnitSpeed("player")
            if issecretvalue and issecretvalue(speed) then
                return
            end
            if type(speed) ~= "number" then
                return
            end
            if speed < 0.5 then
                desiredZoom = maximum
            end
        end
    end

    if desiredZoom ~= targetZoom then
        EaseZoom(desiredZoom)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self.ticker = C_Timer.NewTicker(0.5, UpdateMinimapZoom)
    end
    UpdateMinimapZoom()
end)
