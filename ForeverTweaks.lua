-- A compact minimap button that reloads the interface on a left click.
local button = CreateFrame("Button", "ForeverTweaksReloadButton", Minimap)
button:SetSize(24, 24)
button:SetPoint("CENTER", Minimap, "TOPRIGHT", -6, -6)
button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
button:RegisterForClicks("LeftButtonUp")
-- Use the day/night indicator's native rim around Blizzard's refresh symbol.
local border = button:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)

local function CreateReloadTexture(layer, brightness)
    local texture = button:CreateTexture(nil, layer)
    texture:SetSize(16, 16)
    texture:SetPoint("CENTER")
    texture:SetAtlas("UI-RefreshButton", false)
    texture:SetVertexColor(brightness, brightness, brightness)
    return texture
end

button:SetNormalTexture(CreateReloadTexture("ARTWORK", 1))
button:SetPushedTexture(CreateReloadTexture("ARTWORK", 0.65))
local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)
highlight:SetAlpha(0.35)
button:SetHighlightTexture(highlight, "ADD")
button:SetScript("OnClick", function()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end)

-- The controller maps the left touchpad to PADPADDLE1 and the right to PAD6.
local touchpadBindings = CreateFrame("Frame")
touchpadBindings:RegisterEvent("PLAYER_LOGIN")
touchpadBindings:SetScript("OnEvent", function(self)
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    SetOverrideBinding(self, false, "PAD6", "OPENALLBAGS")
    SetOverrideBinding(self, false, "PADPADDLE1", "TOGGLEWORLDMAP")
    self:UnregisterAllEvents()
end)

-- Hide decorative chat regions without writing settings or firing chat-config events.
local chatInputTextureSuffixes = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local chatInputHeaderKeys = { "header", "headerSuffix", "languageHeader" }
local function RefreshChatInputBackground(editBox)
    local active = editBox:IsShown() and editBox:HasFocus()
    -- Native gamepad close can leave headers shown after releasing a nonempty draft.
    -- Alpha preserves native visibility decisions and header measurements.
    for _, key in ipairs(chatInputHeaderKeys) do
        local header = editBox[key]
        if header then
            header:SetAlpha(active and 1 or 0)
        end
    end
    for _, suffix in ipairs(chatInputTextureSuffixes) do
        local texture = _G[editBox:GetName() .. suffix]
        if texture then
            local isFocusBorder = suffix:sub(1, 5) == "Focus"
            texture:SetAlpha(active and not isFocusBorder and 1 or 0)
        end
    end
end

local function HideChatBackground(name)
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local texture = _G[name .. suffix]
        if texture and texture:IsShown() then
            texture:Hide()
        end
    end
    local editBox = _G[name .. "EditBox"]
    if editBox then
        RefreshChatInputBackground(editBox)
    end
end

-- Show native input artwork only while focused, keeping colored borders hidden.
local configuredChatInputs = setmetatable({}, { __mode = "k" })
local function ConfigureChatInputBackground(chatFrame)
    local editBox = chatFrame and chatFrame.editBox
    if not editBox or configuredChatInputs[editBox] then
        return
    end
    configuredChatInputs[editBox] = true
    for _, script in ipairs({ "OnEditFocusGained", "OnEditFocusLost", "OnShow", "OnHide" }) do
        editBox:HookScript(script, RefreshChatInputBackground)
    end
    RefreshChatInputBackground(editBox)
end

-- Clear canceled drafts only after native gamepad navigation releases chat focus.
local hookedChatBackFrames = setmetatable({}, { __mode = "k" })
local function HookChatGamepadBack(chatFrame)
    if not chatFrame or hookedChatBackFrames[chatFrame]
        or type(chatFrame.SmartNavigationCloseHandler) ~= "function" then
        return
    end

    local editBox = chatFrame.editBox
    if not editBox then
        return
    end

    -- Do not activate chat or write chat/sticky attributes from addon hooks.
    -- Native close handlers read that state before updating protected interact targets.
    hooksecurefunc(chatFrame, "SmartNavigationCloseHandler", function(self)
        if self.editBox then
            self.editBox:SetText("")
            RefreshChatInputBackground(self.editBox)
        end
    end)
    hookedChatBackFrames[chatFrame] = true
end

-- Set message lifetime once per window, preserving native focus and scroll behavior.
local configuredChatFadeFrames = setmetatable({}, { __mode = "k" })
local function ConfigureChatMessageFade(chatFrame)
    if chatFrame and not configuredChatFadeFrames[chatFrame] then
        chatFrame:SetTimeVisible(30)
        configuredChatFadeFrames[chatFrame] = true
    end
end

-- Extend the native right anchor without moving the input's left edge or chat window.
local growingChatInputs = setmetatable({}, { __mode = "k" })
local function UpdateChatInputWidth(editBox)
    local state = growingChatInputs[editBox]
    if not state or not editBox:IsShown() then
        return
    end

    local scale = editBox:GetEffectiveScale()
    local left = editBox:GetLeft()
    local nativeRight = state.scrollBar:GetRight()
    local screenRight = UIParent:GetRight()
    if not left or not nativeRight or not screenRight then
        return
    end
    nativeRight = nativeRight * state.scrollBar:GetEffectiveScale() / scale + 8
    screenRight = (screenRight - 16) * UIParent:GetEffectiveScale() / scale

    local font, size, flags = editBox:GetFont()
    if not font then
        return
    end
    state.measure:SetFont(font, size, flags)
    state.measure:SetText(editBox:GetText())
    local insetLeft, insetRight = editBox:GetTextInsets()
    local desiredRight = left + insetLeft + state.measure:GetUnboundedStringWidth() + insetRight + 8
    local right = math.min(math.max(nativeRight, desiredRight), screenRight)
    local offset = 8 + right - nativeRight
    for index = 1, editBox:GetNumPoints() do
        local point, relativeTo, relativePoint, currentOffset = editBox:GetPoint(index)
        if point == "RIGHT" and relativeTo == state.scrollBar
            and relativePoint == "RIGHT" and currentOffset == offset then
            return
        end
    end
    -- Forever anchors RIGHT to the scrollbar and TOPLEFT to the chat frame.
    editBox:SetPoint("RIGHT", state.scrollBar, "RIGHT", offset, 0)
end

local function ConfigureGrowingChatInput(chatFrame)
    local editBox = chatFrame and chatFrame.editBox
    if not editBox or not chatFrame.ScrollBar then
        return
    end
    if not growingChatInputs[editBox] then
        local measure = editBox:CreateFontString(nil, "ARTWORK")
        measure:Hide()
        growingChatInputs[editBox] = { measure = measure, scrollBar = chatFrame.ScrollBar }
        editBox:HookScript("OnTextChanged", UpdateChatInputWidth)
        editBox:HookScript("OnShow", UpdateChatInputWidth)
    end
    -- Also follows font, header, scale, and chat-window layout changes.
    UpdateChatInputWidth(editBox)
end

-- Keep chat tabs clickable, revealing each only while hovered, over a clear background.
local function UpdateChatTabVisibility()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        HideChatBackground(name)
        ConfigureChatInputBackground(_G[name])
        HookChatGamepadBack(_G[name])
        ConfigureChatMessageFade(_G[name])
        ConfigureGrowingChatInput(_G[name])
        local tab = _G[name .. "Tab"]
        if tab then
            tab:SetAlpha(tab:IsMouseOver() and 1 or 0)
        end
    end
end

local chatTabEvents = CreateFrame("Frame")
chatTabEvents:RegisterEvent("PLAYER_LOGIN")
chatTabEvents:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    UpdateChatTabVisibility()
    -- Blizzard also fades tabs; refresh like UITweaks and discover new tabs each pass.
    self.hoverTicker = C_Timer.NewTicker(0.1, UpdateChatTabVisibility)
end)

-- Use Forever's native opt-out: aura IDs can be secret in addon callbacks.
-- This disables automatic aura popups without reading auras or changing UI queues.
local gamepadSettings = CreateFrame("Frame")
gamepadSettings:RegisterEvent("PLAYER_LOGIN")
gamepadSettings:SetScript("OnEvent", function(self)
    C_CVar.SetCVar("GamepadShowAutoAuraTooltip", "0")
    -- GameTooltip_OnShow hides item tooltips in focused menus when this is enabled.
    C_CVar.SetCVar("GamepadDisableTooltips", "0")
    -- Leave touchpad cursor movement to an external native-mouse mapper.
    C_CVar.SetCVar("GamePadTouchCursorEnable", "0")
    C_CVar.SetCVar("GamePadFactionColor", "0")
    -- Attempt to remove the overlap delay; the client currently retains 2000 ms.
    C_CVar.SetCVar("GamePadOverlapMouseMs", "0")
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Unit tooltips can use ordinary text lines and controller soft-target tokens.
local function IsTooltipValueReadable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function GetTooltipHealthUnit(tooltip, data)
    local _, unit = tooltip:GetUnit()
    if IsTooltipValueReadable(unit) and unit then
        return unit
    end
    -- Only use a fallback token when its GUID matches the displayed tooltip.
    if not IsTooltipValueReadable(data.guid) or not data.guid then
        return
    end
    for _, token in ipairs({ "mouseover", "softenemy", "softfriend", "softinteract", "target" }) do
        local guid = UnitGUID(token)
        if IsTooltipValueReadable(guid) and guid == data.guid then
            return token
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not tooltip.GetUnit or not tooltip.GetLeftLine then
        return
    end
    local unit = GetTooltipHealthUnit(tooltip, data)
    if not unit then
        return
    end
    for _, line in ipairs(data.lines or {}) do
        local label = line.leftText
        local isLevel = line.type == Enum.TooltipDataLineType.UnitLevel
        if not isLevel and IsTooltipValueReadable(label) and type(label) == "string" then
            -- Some client tooltips classify the level as a plain text line.
            local plain = label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            isLevel = plain:find(LEVEL .. " ", 1, true) == 1
        end
        if isLevel and line.lineIndex then
            local text = tooltip:GetLeftLine(line.lineIndex)
            -- UnitHealthMax can be secret. Pass it straight to Blizzard's supported
            -- display sink without inspecting, comparing, or concatenating it.
            text:SetFormattedText("%s - %d HP", label, UnitHealthMax(unit))
            return
        end
    end
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

--@alpha@
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

--@end-alpha@

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
local combatBlend = InCombatLockdown() and 1 or 0
local targetCombatBlend = combatBlend
local fadeDuration = 0.45
local fadeDriver = CreateFrame("Frame")

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

local function RefreshCombatOpacity()
    currentCombatAlpha = outOfCombatAlpha + (inCombatAlpha - outOfCombatAlpha) * combatBlend
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

-- One shared cosine ease keeps all frames synchronized and reverses from current opacity.
local function UpdateCombatOpacity(_, event)
    local desired = InCombatLockdown() and 1 or 0
    if event == "PLAYER_REGEN_DISABLED" then
        desired = 1
    elseif event == "PLAYER_REGEN_ENABLED" then
        desired = 0
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        fadeDriver:SetScript("OnUpdate", nil)
        combatBlend = desired
        targetCombatBlend = desired
    elseif desired ~= targetCombatBlend then
        targetCombatBlend = desired
        local startingBlend = combatBlend
        local elapsedTime = 0
        fadeDriver:SetScript("OnUpdate", function(self, elapsed)
            elapsedTime = elapsedTime + elapsed
            local progress = math.min(elapsedTime / fadeDuration, 1)
            local eased = (1 - math.cos(math.pi * progress)) / 2
            combatBlend = startingBlend + (desired - startingBlend) * eased
            RefreshCombatOpacity()
            if progress == 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
    RefreshCombatOpacity()
end

local opacityEvents = CreateFrame("Frame")
opacityEvents:RegisterEvent("PLAYER_LOGIN")
opacityEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
opacityEvents:RegisterEvent("ADDON_LOADED")
opacityEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
opacityEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
opacityEvents:SetScript("OnEvent", UpdateCombatOpacity)

-- Position and size chat once the initial layout has loaded.
local chatHeightEvents = CreateFrame("Frame")
chatHeightEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
chatHeightEvents:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(0, function()
        if ChatFrame1 then
            ChatFrame1:SetHeight(360)
            -- Leave room for the left-side buttons and gamepad button hints below chat.
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 100)
        end
    end)
end)
