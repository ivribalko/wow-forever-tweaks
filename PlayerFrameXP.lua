-- Display XP in the player name row, following UITweaks' compact percentage style.
local xpText
local hookedContainers = setmetatable({}, { __mode = "k" })

local function UpdatePlayerXP()
    if not xpText then
        return
    end
    PlayerName:SetAlpha(0)
    local maximum = UnitXPMax("player")
    if PlayerFrame.unit ~= "player" or not GameRulesUtil.CanShowExperienceBar() or maximum <= 0 then
        xpText:Hide()
        return
    end
    local percentage = math.floor(UnitXP("player") / maximum * 100)
    local rested = GetXPExhaustion()
    if rested and rested > 0 then
        xpText:SetFormattedText("%d%% (+%d%%)", percentage, math.floor(rested / maximum * 100))
    else
        xpText:SetFormattedText("%d%%", percentage)
    end
    xpText:Show()
end

-- Mask artwork without hooking Blizzard's bar-assignment or animation methods.
local function HideOriginalXP(container)
    local experience = StatusTrackingBarInfo.BarsEnum.Experience
    local bar = container.bars and container.bars[experience]
    if bar then
        bar:SetAlpha(0)
        bar:EnableMouse(false)
    end
    local alpha = container.shownBarIndex == experience and 0 or 1
    if container.BarFrameTexture then
        container.BarFrameTexture:SetAlpha(alpha)
    end
    if container.HorizontalDividersPool then
        for divider in container.HorizontalDividersPool:EnumerateActive() do
            divider:SetAlpha(alpha)
        end
    end
end

local function InitializePlayerXP()
    if not xpText and PlayerFrame and PlayerName then
        local content = PlayerFrame.PlayerFrameContent
        local main = content and content.PlayerFrameContentMain
        if main then
            xpText = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall", 1)
            -- A single anchor and automatic width keep the rested suffix untruncated.
            xpText:SetHeight(12)
            xpText:SetWordWrap(false)
            -- Forever's level badge is below the portrait, separate from the name row.
            xpText:SetPoint("RIGHT", PlayerName, "RIGHT", 0, 0)
            xpText:SetJustifyH("RIGHT")
            xpText:SetTextColor(1, 0.82, 0)
            for _, name in ipairs({ "PlayerFrame_UpdateRolesAssigned", "PlayerFrame_ToPlayerArt", "PlayerFrame_ToVehicleArt" }) do
                hooksecurefunc(name, UpdatePlayerXP)
            end
        end
    end
    local manager = StatusTrackingBarManager
    if xpText and manager and manager.barContainers then
        for _, container in ipairs(manager.barContainers) do
            if not hookedContainers[container] then
                -- Native fades can switch bars and rebuild dividers while already shown.
                container:HookScript("OnUpdate", HideOriginalXP)
                hookedContainers[container] = true
            end
            HideOriginalXP(container)
        end
    end
    UpdatePlayerXP()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("UPDATE_EXHAUSTION")
events:RegisterEvent("PLAYER_LEVEL_CHANGED")
events:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
events:RegisterEvent("ENABLE_XP_GAIN")
events:RegisterEvent("DISABLE_XP_GAIN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        InitializePlayerXP()
    else
        UpdatePlayerXP()
    end
end)
