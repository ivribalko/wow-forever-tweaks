-- Secure controller routing swaps the main and R2 panels during combat.
local driver = CreateFrame("Frame")
local latch, page
local refreshPending = true
local names = { "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar" }

local REFRESH = [[
    if self:GetAttribute("refreshing") then return end
    self:SetAttribute("refreshing", true)
    local selected = 1
    if self:GetAttribute("left") then
        selected = self:GetAttribute("right") and 4 or 2
    elseif self:GetAttribute("right") then
        selected = 3
    end
    -- Swap only the unmodified and R2 panels; L2 combinations stay native.
    if self:GetAttribute("state-combat") == "combat" and not self:GetAttribute("left") then
        selected = selected == 1 and 3 or 1
    end
    local stance = self:GetAttribute("stance")
    if self:GetAttribute("state-combat") ~= "combat" then
        -- Use Blizzard's completed override state outside combat, including
        -- activation/deactivation that follows the form state-driver update.
        if selected == self:GetAttribute("native-stance") then selected = 5 end
    elseif selected == stance and HasBonusActionBar()
        and self:GetFrameRef("button-2-1"):GetID() == self:GetAttribute("stance-page") then
        selected = 5
    end
    self:SetAttribute("selected", selected)
    if self:GetAttribute("enabled") then
        for i = 1, self:GetAttribute("keys") do
            local button = self:GetFrameRef("button-" .. selected .. "-" .. self:GetAttribute("slot-" .. i))
            self:SetBindingClick(true, self:GetAttribute("key-" .. i), button:GetName(), "LeftButton")
        end
        if self:GetAttribute("compact") then
            for i = 1, 5 do
                local bar = self:GetFrameRef("bar-" .. i)
                if i == selected then bar:Show() else bar:Hide() end
            end
        end
    end
    self:SetAttribute("refreshing", nil)
]]

-- Each trigger has a separate click target so overlapping presses do not
-- share a button's press/release tracking.
local CLICK = [[
    local owner = self:GetFrameRef("owner")
    if not owner:GetAttribute("enabled") then return end
    owner:SetAttribute(self:GetAttribute("trigger"), down or nil)
    owner:RunAttribute("refresh")
]]

local RESET = [[
    self:ClearBindings()
    self:SetAttribute("left", nil)
    self:SetAttribute("right", nil)
    if self:GetAttribute("enabled") then
        self:SetBindingClick(true, "PADLTRIGGER", self:GetFrameRef("trigger-left"):GetName(), "LeftButton")
        self:SetBindingClick(true, "PADRTRIGGER", self:GetFrameRef("trigger-right"):GetName(), "LeftButton")
        self:RunAttribute("refresh")
    end
]]

-- Resume after temporary native targeting panels close, including in combat.
local RESUME = [[
    if not self:GetAttribute("resume-enabled") or self:GetAttribute("state-special") == "blocked" then return end
    for i = 1, self:GetAttribute("override-count") do
        if self:GetFrameRef("override-" .. i):IsShown() then return end
    end
    self:SetAttribute("resume-enabled", nil)
    self:SetAttribute("enabled", true)
    self:RunAttribute("reset")
]]

--@alpha@
-- Capture panel transitions without changing native frames or their routing.
local lastPanelSignature
local panelCaptureSequence = 0
local function CapturePanelTransition(source, detail)
    if not latch or not page then return end
    local states = {}
    for _, name in ipairs(names) do
        local bar = page.actionBars[name]
        states[#states + 1] = name .. ":" .. (bar:IsShown() and "shown" or "hidden")
            .. (bar:IsProtected() and ":protected" or ":unprotected")
            .. (select(2, bar:IsProtected()) and ":explicit" or ":inherited")
            .. (bar:IsVisible() and ":visible" or ":not-visible")
    end
    local native = "other"
    for _, name in ipairs(names) do
        if page:GetActiveBar() == page.actionBars[name] then native = name end
    end
    local entry = {
        source = source,
        detail = detail,
        page = page:GetCurrentPage(),
        parentVisible = page:IsVisible(),
        refreshing = not not latch:GetAttribute("refreshing"),
        stance = latch:GetAttribute("stance"),
        nativeStance = latch:GetAttribute("native-stance"),
        form = GetShapeshiftForm(),
        combat = InCombatLockdown(),
        selected = latch:GetAttribute("selected"),
        enabled = latch:GetAttribute("enabled"),
        compact = latch:GetAttribute("compact"),
        stateCombat = latch:GetAttribute("state-combat"),
        heldLeft = not not latch:GetAttribute("left"),
        heldRight = not not latch:GetAttribute("right"),
        physicalLeft = not not IsKeyDown("PADLTRIGGER"),
        physicalRight = not not IsKeyDown("PADRTRIGGER"),
        native = native,
        bars = table.concat(states, ","),
    }
    local signature = entry.bars .. ":" .. native
    for _, key in ipairs({"combat", "selected", "enabled", "compact", "stateCombat",
        "heldLeft", "heldRight", "physicalLeft", "physicalRight"}) do
        signature = signature .. ":" .. tostring(entry[key])
    end
    if source == "sample" and signature == lastPanelSignature then return end
    lastPanelSignature = signature
    if type(ForeverTweaksDiagnostics) ~= "table" then ForeverTweaksDiagnostics = {} end
    local captures = ForeverTweaksDiagnostics.panelTransitions or {}
    ForeverTweaksDiagnostics.panelTransitions = captures
    panelCaptureSequence = panelCaptureSequence + 1
    entry.sequence = panelCaptureSequence
    entry.elapsed = GetTime()
    entry.stack = source ~= "sample" and debugstack(2, 8, 0) or nil
    captures[#captures + 1] = entry
    if #captures > 120 then table.remove(captures, 1) end
end
--@end-alpha@

local function Install()
    if latch or InCombatLockdown() or not GamepadMainActionBarFrame then return end
    page = GamepadMainActionBarFrame.PageUnit
    if not page or not page.actionBars.stanceBar then return end
    latch = CreateFrame("Button", "ForeverTweaksCombatPanels", UIParent,
        "SecureHandlerClickTemplate,SecureHandlerStateTemplate")
    latch:EnableMouse(false)
    latch:SetAttribute("keys", 0)
    latch:SetAttribute("refresh", REFRESH)
    latch:SetAttribute("reset", RESET)
    latch:SetAttribute("resume", RESUME)
    latch:SetAttribute("override-count", 0)
    for _, side in ipairs({ "left", "right" }) do
        local trigger = CreateFrame("Button", "ForeverTweaksCombatTrigger_" .. side, UIParent,
            "SecureHandlerClickTemplate")
        trigger:RegisterForClicks("AnyDown", "AnyUp")
        trigger:EnableMouse(false)
        trigger:SetFrameRef("owner", latch)
        trigger:SetAttribute("trigger", side)
        trigger:SetAttribute("_onclick", CLICK)
        latch:SetFrameRef("trigger-" .. side, trigger)
    end
    for i, name in ipairs(names) do
        local bar = page.actionBars[name]
        latch:SetFrameRef("bar-" .. i, bar)
        for slot = 1, 8 do
            local button = bar:GetActionButtonByIndex(slot)
            latch:SetFrameRef("button-" .. i .. "-" .. slot, button)
        end
        -- The native bars inherit protection from their buttons. Secure
        -- wrappers cannot obtain an explicitly protected handle for the bar.
        -- This child has its own protection and follows parent visibility.
        local visibilityDriver = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
        for _, script in ipairs({ "OnShow", "OnHide" }) do
            SecureHandlerWrapScript(visibilityDriver, script, latch,
                [[ control:RunAttribute("refresh") ]])
            --@alpha@
            bar:HookScript(script, function()
                CapturePanelTransition("bar-visibility", name .. ":" .. script)
            end)
            --@end-alpha@
        end
        visibilityDriver:Show()
    end
    --@alpha@
    hooksecurefunc(page, "RefreshActionBarVisibilities", function()
        CapturePanelTransition("native-visibility")
    end)
    hooksecurefunc(page, "SetActiveActionBar", function()
        CapturePanelTransition("native-selection")
    end)
    latch:HookScript("OnAttributeChanged", function(_, attribute, value)
        if attribute == "selected" or attribute == "left" or attribute == "right"
            or attribute == "enabled" or attribute == "state-combat"
            or attribute == "state-form" or attribute == "state-special"
            or (attribute == "refreshing" and not value) then
            CapturePanelTransition("secure-state", attribute .. "=" .. tostring(value))
        end
    end)
    local captureEvents = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UPDATE_SHAPESHIFT_FORM", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED"}) do
        captureEvents:RegisterEvent(event)
    end
    captureEvents:SetScript("OnEvent", function(_, event)
        CapturePanelTransition("event", event)
    end)
    C_Timer.NewTicker(0.05, function() CapturePanelTransition("sample") end)
    --@end-alpha@
    -- Queue a refresh after native slot updates and override activation finish.
    hooksecurefunc(page.actionBars.stanceBar, "UpdateStanceBarState", function()
        refreshPending = true
    end)
    -- Native stance buttons update their own spell slots in every form.
    latch:SetAttribute("_onstate-form", [[ self:RunAttribute("refresh") ]])
    latch:SetAttribute("_onstate-combat", [[ self:RunAttribute("refresh") ]])
    RegisterStateDriver(latch, "combat", "[combat]combat;peace")
    RegisterStateDriver(latch, "form", "[form:1]1;[form:2]2;[form:3]3;[form:4]4;[form:5]5;[form:6]6;[form:7]7;[form:8]8;0")
    latch:SetAttribute("_onstate-special", [[
        if newstate == "blocked" then
            if self:GetAttribute("enabled") then self:SetAttribute("resume-enabled", true) end
            self:SetAttribute("enabled", false)
            self:RunAttribute("reset")
        else
            self:RunAttribute("resume")
        end
    ]])
    RegisterStateDriver(latch, "special", "[vehicleui][possessbar][overridebar]blocked;ready")
    local overrideCount = 0
    for _, bar in ipairs(page.overrideBars) do
        if bar ~= page.actionBars.stanceBar then
            overrideCount = overrideCount + 1
            latch:SetFrameRef("override-" .. overrideCount, bar)
            local overrideDriver = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
            SecureHandlerWrapScript(overrideDriver, "OnShow", latch, [[
                if control:GetAttribute("enabled") then control:SetAttribute("resume-enabled", true) end
                control:SetAttribute("enabled", false)
                control:RunAttribute("reset")
            ]])
            SecureHandlerWrapScript(overrideDriver, "OnHide", latch,
                [[ control:RunAttribute("resume") ]])
            overrideDriver:Show()
        end
    end
    latch:SetAttribute("override-count", overrideCount)
end

local dirty = true
local function Update()
    Install()
    if not latch or InCombatLockdown() then return end
    local enabled = latch:GetAttribute("state-special") ~= "blocked"
        and InputUtil.IsGamepadUIEnabled() and page:IsVisible()
        and page:GetCurrentPage() <= 3
        and GamepadSharedUtility.InputBindingManager:IsOnlyCoreBindingSetActive()
        and not GamepadMode.IsHUDBindingModifierDown() and not GamepadMode.IsTargetingModifierDown()
    for _, bar in ipairs(page.overrideBars) do
        if bar ~= page.actionBars.stanceBar and bar:IsShown() then enabled = false end
    end
    local stance = page.actionBars.stanceBar
    local setting = stance:GetOverrideCVarValue()
    local compact = not not page:ShouldUseCompactLayout()
    if dirty or enabled ~= latch:GetAttribute("enabled")
        or setting ~= latch:GetAttribute("setting") or compact ~= latch:GetAttribute("compact") then
        latch:SetAttribute("resume-enabled", nil)
        latch:SetAttribute("enabled", false)
        latch:Execute(RESET)
        local position = 0
        for i, name in ipairs(names) do
            if stance:GetActionBarLinkedWithOverrideBar() == page.actionBars[name] then position = i end
        end
        local stancePage = stance:GetLinkedOverrideBarPage(setting)
        latch:SetAttribute("stance", position)
        latch:SetAttribute("stance-page", stancePage and stancePage > 0
            and GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(stancePage, 9) or 0)
        latch:SetAttribute("setting", setting)
        latch:SetAttribute("compact", compact)
        local count = 0
        for slot = 1, 8 do
            for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. slot, 1) }) do
                if key:find("PAD", 1, true) then
                    count = count + 1
                    latch:SetAttribute("key-" .. count, key)
                    latch:SetAttribute("slot-" .. count, slot)
                end
            end
        end
        latch:SetAttribute("keys", count)
        latch:SetAttribute("enabled", enabled and count > 0)
        latch:Execute(RESET)
        dirty = false
    end
    local nativeStance = 0
    for i = 1, 4 do
        if stance:IsBarActivelyOverridingActionBar(page.actionBars[names[i]]) then
            nativeStance = i
            break
        end
    end
    if nativeStance ~= latch:GetAttribute("native-stance") then
        latch:SetAttribute("native-stance", nativeStance)
        refreshPending = true
    end
    if refreshPending then
        -- Run after native event handlers finish updating form slots/layout.
        -- Combat changes use the secure click, visibility, and form handlers;
        -- retain this request until ordinary execution is allowed again.
        latch:Execute(REFRESH)
        refreshPending = false
    end
end

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("UPDATE_BINDINGS")
driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
driver:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
driver:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
driver:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
local updateQueued = false
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "UPDATE_BINDINGS" then dirty = true end
    refreshPending = true
    if event == "PLAYER_LOGIN" then C_Timer.NewTicker(0.1, Update) end
    if not updateQueued then
        updateQueued = true
        C_Timer.After(0, function()
            updateQueued = false
            Update()
        end)
    end
end)
