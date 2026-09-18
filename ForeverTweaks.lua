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
