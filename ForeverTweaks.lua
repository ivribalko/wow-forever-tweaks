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

-- Hide decorative chat regions without writing settings or firing chat-config events.
local focusedChatFrames = setmetatable({}, { __mode = "k" })
local chatInputOwners = setmetatable({}, { __mode = "k" })
local function IsChatExpanded(chatFrame)
    if not chatFrame then
        return false
    end
    for frame, state in pairs(focusedChatFrames) do
        if state.alpha > 0 and (frame == chatFrame
            or (frame.isDocked and chatFrame.isDocked and frame.dock
                and frame.dock == chatFrame.dock)) then
            return true
        end
    end
    return false
end

local function RefreshChatTab(chatFrame)
    local tab = _G[chatFrame:GetName() .. "Tab"]
    if tab then
        UIFrameFadeRemoveFrame(tab)
        tab:SetAlpha((IsChatExpanded(chatFrame) or tab:IsMouseOver()) and 1 or 0)
    end
end

local chatInputTextureSuffixes = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local chatInputHeaderKeys = { "header", "headerSuffix", "languageHeader" }
local function RefreshChatInputBackground(editBox)
    local expanded = IsChatExpanded(chatInputOwners[editBox])
    local active = editBox:IsShown() and (editBox:HasFocus() or expanded)
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
            texture:SetAlpha(active and (not isFocusBorder or expanded) and 1 or 0)
        end
    end
end

local function HideChatBackground(name)
    local state = focusedChatFrames[_G[name]]
    if state then
        state.refreshArtwork()
    end
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local texture = _G[name .. suffix]
        if not state and texture and texture:IsShown() then
            texture:Hide()
        end
    end
    local editBox = _G[name .. "EditBox"]
    if editBox then
        RefreshChatInputBackground(editBox)
    end
end

-- Show native input artwork while focused, including colored borders in expanded chat.
local configuredChatInputs = setmetatable({}, { __mode = "k" })
local function ConfigureChatInputBackground(chatFrame)
    local editBox = chatFrame and chatFrame.editBox
    if not editBox or configuredChatInputs[editBox] then
        return
    end
    configuredChatInputs[editBox] = true
    chatInputOwners[editBox] = chatFrame
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

-- Temporarily enlarge the native dock owner and show its original artwork on gamepad focus.
local function ConfigureGamepadChatFocus(chatFrame)
    if not chatFrame or focusedChatFrames[chatFrame]
        or type(chatFrame.FocusGamepad) ~= "function"
        or type(chatFrame.UnfocusGamepad) ~= "function" then
        return
    end

    local driver = CreateFrame("Frame")
    local state = { driver = driver, alpha = 0 }
    focusedChatFrames[chatFrame] = state

    function state.refreshArtwork()
        local opacity = math.max(chatFrame.oldAlpha or DEFAULT_CHATFRAME_ALPHA, DEFAULT_CHATFRAME_ALPHA)
        for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
            local texture = _G[chatFrame:GetName() .. suffix]
            if texture then
                -- Cancel native hover fades so they cannot delay or override focus visibility.
                UIFrameFadeRemoveFrame(texture)
                local expanded = IsChatExpanded(chatFrame)
                texture:SetAlpha(expanded and opacity or 0)
                texture:SetShown(expanded)
            end
        end
    end

    local function SetChatArtworkVisible(visible)
        state.alpha = visible and 1 or 0
        -- Docked tabs share the expanded window, including their native artwork.
        for frame, frameState in pairs(focusedChatFrames) do
            frameState.refreshArtwork()
            RefreshChatTab(frame)
            if frame.editBox then
                RefreshChatInputBackground(frame.editBox)
            end
        end
    end

    local function RestoreChat()
        if state.owner then
            local owner, height, width, points = state.owner, state.height, state.width, state.points
            state.owner, state.height, state.width, state.points = nil, nil, nil, nil
            owner:ClearAllPoints()
            owner:SetSize(width, height)
            for _, point in ipairs(points) do
                owner:SetPoint(unpack(point, 1, 5))
            end
        end
        SetChatArtworkVisible(false)
    end

    hooksecurefunc(chatFrame, "FocusGamepad", function(self)
        if not state.owner then
            -- Docked tabs inherit the primary frame's geometry through native anchors.
            local owner = self.isDocked and self.dock and self.dock.primary or self
            local left, bottom = owner:GetLeft(), owner:GetBottom()
            if not left or not bottom then
                return
            end
            state.owner, state.height, state.width = owner, owner:GetHeight(), owner:GetWidth()
            state.points = {}
            for index = 1, owner:GetNumPoints() do
                state.points[index] = { owner:GetPoint(index) }
            end
            -- Pin the existing bottom-left corner so all extra height extends upward.
            local scale = UIParent:GetEffectiveScale() / owner:GetEffectiveScale()
            local bottomOffset = bottom - UIParent:GetBottom() * scale
            -- Mirror the bottom screen margin above the expanded chat frame.
            local expandedHeight = UIParent:GetHeight() * scale - 2 * bottomOffset
            owner:ClearAllPoints()
            owner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                left - UIParent:GetLeft() * scale, bottomOffset)
            owner:SetSize(state.width, math.max(state.height, expandedHeight))
        end
        SetChatArtworkVisible(true)
    end)
    hooksecurefunc(chatFrame, "UnfocusGamepad", RestoreChat)
    chatFrame:HookScript("OnHide", RestoreChat)
    driver:RegisterEvent("PLAYER_LOGOUT")
    driver:SetScript("OnEvent", RestoreChat)
end

-- Native hover transitions must not restart artwork fades after a focus transition.
for _, functionName in ipairs({ "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame" }) do
    hooksecurefunc(functionName, function(chatFrame)
        local state = focusedChatFrames[chatFrame]
        if state then
            state.refreshArtwork()
            RefreshChatTab(chatFrame)
        end
    end)
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

-- Reveal all tabs in an expanded dock; otherwise reveal each only while hovered.
local function UpdateChatTabVisibility()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        HideChatBackground(name)
        ConfigureChatInputBackground(_G[name])
        HookChatGamepadBack(_G[name])
        ConfigureGamepadChatFocus(_G[name])
        ConfigureChatMessageFade(_G[name])
        ConfigureGrowingChatInput(_G[name])
        if _G[name] then
            RefreshChatTab(_G[name])
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
