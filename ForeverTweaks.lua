-- A compact minimap button that reloads the interface on a left click.
local button = CreateFrame("Button", "ForeverTweaksReloadButton", Minimap)
button:SetSize(24, 24)
button:SetPoint("CENTER", Minimap, "TOPRIGHT", -6, -6)
button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
button:RegisterForClicks("LeftButtonUp")
button:SetNormalTexture("Interface\\AddOns\\ForeverTweaks\\Reload.tga")
button:SetPushedTexture("Interface\\AddOns\\ForeverTweaks\\Reload.tga")
button:GetPushedTexture():SetVertexColor(0.65, 0.65, 0.65)
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
button:SetScript("OnClick", function()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end)

-- Use Forever's native opt-out: aura IDs can be secret in addon callbacks.
-- This disables automatic aura popups without reading auras or changing UI queues.
local auraSettings = CreateFrame("Frame")
auraSettings:RegisterEvent("PLAYER_LOGIN")
auraSettings:SetScript("OnEvent", function(self)
    C_CVar.SetCVar("GamepadShowAutoAuraTooltip", "0")
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Keep the beta's floating Issue Reporter panel hidden when it loads or reopens.
local hiddenIssueReporter
local hookedQuestReporter
local hiddenQuestSurveys = setmetatable({}, { __mode = "k" })

-- Quest reward feedback is a separate survey parented to UIParent, not the reporter.
local function HideQuestFeedback()
    local reporter = PTR_IssueReporter
    local surveys = reporter and reporter.Data and reporter.Data.FrameAttachedSurveyFrames
    local survey = surveys and QuestFrame and surveys[QuestFrame]
    if not survey then
        return
    end
    if not hiddenQuestSurveys[survey] then
        survey:HookScript("OnShow", function(self)
            self:Hide()
        end)
        hiddenQuestSurveys[survey] = true
    end
    survey:Hide()
end

local function HideIssueReporter()
    local reporter = PTR_IssueReporter
    if not reporter then
        return
    end
    if hiddenIssueReporter ~= reporter then
        reporter:HookScript("OnShow", function(self)
            self:Hide()
        end)
        hiddenIssueReporter = reporter
    end
    reporter:Hide()
    if hookedQuestReporter ~= reporter and reporter.PopFrameAttachedSurvey then
        hooksecurefunc(reporter, "PopFrameAttachedSurvey", HideQuestFeedback)
        hookedQuestReporter = reporter
    end
    HideQuestFeedback()
end

local reporterEvents = CreateFrame("Frame")
reporterEvents:RegisterEvent("ADDON_LOADED")
reporterEvents:RegisterEvent("PLAYER_LOGIN")
reporterEvents:SetScript("OnEvent", HideIssueReporter)
HideIssueReporter()

-- Persist a bounded record of protected-action failures for diagnosis after reload.
local diagnosticEvents = CreateFrame("Frame")
diagnosticEvents:RegisterEvent("ADDON_ACTION_BLOCKED")
diagnosticEvents:RegisterEvent("ADDON_ACTION_FORBIDDEN")
diagnosticEvents:SetScript("OnEvent", function(_, event, addon, action)
    if type(ForeverTweaksDiagnostics) ~= "table" then
        ForeverTweaksDiagnostics = {}
    end
    local entries = ForeverTweaksDiagnostics
    entries[#entries + 1] = {
        event = event,
        addon = addon,
        action = action,
        elapsed = GetTime(),
        combat = InCombatLockdown(),
        questShown = QuestFrame and QuestFrame:IsShown() or false,
        stack = debugstack(2, 16, 16),
    }
    if #entries > 20 then
        table.remove(entries, 1)
    end
end)

-- Apply combat-dependent opacity to the unit frames, player cast bars, and gamepad bars.
local combatOpacityFrames = {
    "PlayerFrame",
    "TargetFrame",
    "GamepadMainActionBarFrame",
    "PlayerCastingBarFrame",
    "GamepadPlayerCastingBarFrame",
}
local hookedOpacityFrames = setmetatable({}, { __mode = "k" })
local outOfCombatAlpha = 0.4
local inCombatAlpha = 0.7
local currentCombatAlpha = outOfCombatAlpha

-- Track native cast-bar alpha separately so repeated updates never compound it.
local castBarNativeAlpha = setmetatable({}, { __mode = "k" })
local settingCastBarAlpha = false

local function ApplyCombatOpacity(frame)
    settingCastBarAlpha = true
    frame:SetAlpha(currentCombatAlpha * (castBarNativeAlpha[frame] or 1))
    settingCastBarAlpha = false
end

-- Catch both ApplyAlpha and direct SetAlpha calls without replacing Blizzard methods.
local function ApplyCastBarOpacity(frame, alpha)
    if settingCastBarAlpha then
        return
    end
    castBarNativeAlpha[frame] = alpha
    ApplyCombatOpacity(frame)
end

-- Native animation alpha bypasses SetAlpha; cap the hold and fade endpoints too.
local function UpdateCastBarFadeOpacity(frame)
    for _, name in ipairs({ "FadeOutAnim", "HoldFadeOutAnim" }) do
        local group = frame[name]
        if group then
            local animations = { group:GetAnimations() }
            for index, animation in ipairs(animations) do
                animation:SetFromAlpha(currentCombatAlpha)
                animation:SetToAlpha(index == #animations and 0 or currentCombatAlpha)
            end
        end
    end
end

local function UpdateCombatOpacity(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        currentCombatAlpha = inCombatAlpha
    elseif event == "PLAYER_REGEN_ENABLED" then
        currentCombatAlpha = outOfCombatAlpha
    else
        currentCombatAlpha = InCombatLockdown() and inCombatAlpha or outOfCombatAlpha
    end

    for _, name in ipairs(combatOpacityFrames) do
        local frame = _G[name]
        if frame then
            if not hookedOpacityFrames[frame] then
                frame:HookScript("OnShow", ApplyCombatOpacity)
                if name == "PlayerCastingBarFrame" or name == "GamepadPlayerCastingBarFrame" then
                    castBarNativeAlpha[frame] = 1
                    hooksecurefunc(frame, "SetAlpha", ApplyCastBarOpacity)
                end
                hookedOpacityFrames[frame] = true
            end
            if castBarNativeAlpha[frame] then
                UpdateCastBarFadeOpacity(frame)
            end
            ApplyCombatOpacity(frame)
        end
    end
end

local opacityEvents = CreateFrame("Frame")
opacityEvents:RegisterEvent("PLAYER_LOGIN")
opacityEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
opacityEvents:RegisterEvent("ADDON_LOADED")
opacityEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
opacityEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
opacityEvents:SetScript("OnEvent", UpdateCombatOpacity)

-- Set chat to three times its 120-unit default once the initial layout has loaded.
local chatHeightEvents = CreateFrame("Frame")
chatHeightEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
chatHeightEvents:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(0, function()
        if ChatFrame1 then
            ChatFrame1:SetHeight(360)
        end
    end)
end)
