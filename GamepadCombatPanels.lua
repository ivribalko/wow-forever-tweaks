-- Secure controller routing swaps the main and R2 panels during combat.
local driver = CreateFrame("Frame")
local latch, page
local refreshPending = true
local names = { "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar" }

-- Native left-square/right-circle geometry from Forever ActionBarStyles.lua.
-- Only frame geometry is applied; native button methods remain untouched.
local layouts = {
    collapsed = { width = 208, height = 68, square = 32, circle = 30,
        x = { -92, -58, -24, -58, 25, 55, 85, 55 },
        y = { 0, 17, 0, -17, 0, 18, 0, -18 } },
    expanded = { width = 266, height = 86, square = 40, circle = 38,
        x = { -119, -75, -31, -75, 32, 70, 108, 70 },
        y = { 0, 23, 0, -23, 0, 23, 0, -23 } },
}

local APPEARANCE = [[
    if not self:GetAttribute("enabled") then return end
    local selected = self:GetAttribute("selected")
    for i = 1, 5 do
        local bar = self:GetFrameRef("bar-" .. i)
        local active = i == selected
        local layout = active and self:GetAttribute("scaling") and "expanded" or "collapsed"
        bar:SetWidth(self:GetAttribute(layout .. "-width"))
        bar:SetHeight(self:GetAttribute(layout .. "-height"))
        bar:SetFrameLevel(active and 5 or 4)
        for slot = 1, 8 do
            local button = self:GetFrameRef("button-" .. i .. "-" .. slot)
            local size = self:GetAttribute(layout .. (slot <= 4 and "-square" or "-circle"))
            button:SetWidth(size)
            button:SetHeight(size)
            button:ClearAllPoints()
            button:SetPoint("CENTER", self:GetFrameRef("anchor-" .. i), "CENTER",
                self:GetAttribute(layout .. "-x-" .. slot), self:GetAttribute(layout .. "-y-" .. slot))
        end
    end
    self:CallMethod("RefreshFocusTextures")
]]

-- Texture-only presentation must not invoke native ShowHighlight or styling
-- methods: those replace functions subsequently used by protected spell clicks.
local updatingFocusTextures = false
local function RefreshFocusTextures(self)
    if updatingFocusTextures or not self:GetAttribute("enabled") then return end
    updatingFocusTextures = true
    local selected = self:GetAttribute("selected")
    local highlight = GetCVarBool("GamepadShowActionBarHighlight")
    for i, name in ipairs(names) do
        page.actionBars[name].BackgroundFocus:SetShown(i == selected and highlight)
    end
    updatingFocusTextures = false
end

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
    self:RunAttribute("appearance")
    self:SetAttribute("refreshing", nil)
]]

local CLICK = [[
    if not self:GetAttribute("enabled") then return end
    if button ~= "left" and button ~= "right" then return end
    if not down and self:GetAttribute("left") and self:GetAttribute("right") then
        -- Releasing either side of L2+R2 releases the whole combination,
        -- even if the other trigger's release never reaches this handler.
        self:SetAttribute("left", nil)
        self:SetAttribute("right", nil)
    else
        self:SetAttribute(button, down or nil)
    end
    self:RunAttribute("refresh")
]]

local RESET = [[
    self:ClearBindings()
    self:SetAttribute("left", nil)
    self:SetAttribute("right", nil)
    if self:GetAttribute("enabled") then
        self:SetBindingClick(true, "PADLTRIGGER", self:GetName(), "left")
        self:SetBindingClick(true, "PADRTRIGGER", self:GetName(), "right")
        self:RunAttribute("refresh")
    end
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
    latch.RefreshFocusTextures = RefreshFocusTextures
    latch:SetAttribute("appearance", APPEARANCE)
    for layout, values in pairs(layouts) do
        for _, key in ipairs({ "width", "height", "square", "circle" }) do
            latch:SetAttribute(layout .. "-" .. key, values[key])
        end
        for slot = 1, 8 do
            latch:SetAttribute(layout .. "-x-" .. slot, values.x[slot])
            latch:SetAttribute(layout .. "-y-" .. slot, values.y[slot])
        end
    end
    latch:RegisterForClicks("AnyDown", "AnyUp")
    latch:EnableMouse(false)
    latch:SetAttribute("keys", 0)
    latch:SetAttribute("refresh", REFRESH)
    latch:SetAttribute("reset", RESET)
    latch:SetAttribute("_onclick", CLICK)
    for i, name in ipairs(names) do
        local bar = page.actionBars[name]
        latch:SetFrameRef("bar-" .. i, bar)
        for slot = 1, 8 do
            local button = bar:GetActionButtonByIndex(slot)
            latch:SetFrameRef("button-" .. i .. "-" .. slot, button)
            SecureHandlerWrapScript(button, "OnClick", latch, [[
                return nil, true
            ]], [[ control:RunAttribute("refresh") ]])
        end
        -- The native bars inherit protection from their buttons. Secure
        -- wrappers cannot obtain an explicitly protected handle for the bar.
        -- This child has its own protection and follows parent visibility.
        local visibilityDriver = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
        -- Restricted SetPoint requires an explicitly protected relative frame,
        -- even outside combat. Keep this anchor centered on the native bar.
        visibilityDriver:SetPoint("CENTER", bar, "CENTER")
        latch:SetFrameRef("anchor-" .. i, visibilityDriver)
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
    hooksecurefunc(page, "SetActiveActionBar", function()
        RefreshFocusTextures(latch)
    end)
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
        self:SetAttribute("enabled", false)
        self:RunAttribute("reset")
    ]])
    RegisterStateDriver(latch, "special", "[vehicleui][possessbar][overridebar]blocked;ready")
    for _, bar in ipairs(page.overrideBars) do
        if bar ~= page.actionBars.stanceBar then
            local overrideDriver = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
            SecureHandlerWrapScript(overrideDriver, "OnShow", latch, [[
                control:SetAttribute("enabled", false)
                control:RunAttribute("reset")
            ]])
            overrideDriver:Show()
        end
    end
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
    local scaling = GetCVarBool("GamepadShowActionBarScaling")
    local highlight = GetCVarBool("GamepadShowActionBarHighlight")
    if scaling ~= latch:GetAttribute("scaling") or highlight ~= latch:GetAttribute("highlight") then
        latch:SetAttribute("scaling", scaling)
        latch:SetAttribute("highlight", highlight)
        refreshPending = true
    end
    if dirty or enabled ~= latch:GetAttribute("enabled")
        or setting ~= latch:GetAttribute("setting") or compact ~= latch:GetAttribute("compact") then
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
