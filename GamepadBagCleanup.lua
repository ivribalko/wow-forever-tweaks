-- Adds an isolated R3 cleanup shortcut and visual hint to the inventory footer.
local driver = CreateFrame("Frame")
local owner, button, hint, hintLegend
local KEY = "PADRSTICK"
local CLICK = "CLICK ForeverTweaksBagCleanup:LeftButton"

local function GetFooter()
    local bags = ContainerFrameCombinedBags
    return bags and bags:IsShown() and bags.gamepadFooter
end

local function InventoryHasFocus(footer)
    if not footer or not footer.isShown or not footer.inputLegend
        or not footer.inputLegend:IsVisible() then return false end
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    local stack = manager and manager.bindingSetStack
    local top = stack and stack[#stack]
    -- A popup, item menu, or Bind picker takes priority over bag cleanup.
    return top and footer.bindings and top.name == footer.bindings.name
        and not GetCurrentKeyBoardFocus()
        and not GamepadSharedUtility.IsSuspendFooterShown()
end

local function CanCleanUp(footer)
    return not InCombatLockdown() and InventoryHasFocus(footer) and not GetCursorInfo()
end

local function RefreshHint(legend, visible, enabled)
    local container = legend.promptContainerFrame
    if not container then return end
    if not hint then
        hint = CreateFrame("Frame", nil, container)
        hint.ignoreInLayout = true
        hint:SetHeight(24)
        hint.Icon = hint:CreateTexture(nil, "ARTWORK")
        hint.Icon:SetSize(24, 24)
        hint.Icon:SetPoint("LEFT")
        local label = hint:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", hint.Icon, "RIGHT", 5, 0)
        label:SetText(BAG_CLEANUP_BAGS or "Clean Up Bags")
        hint:SetWidth(label:GetStringWidth() + 29)
    end
    hint:SetParent(container)
    hintLegend = legend

    -- Read native prompt bounds afresh; never register in native layout tables
    -- or hook their methods, which run in protected controller focus paths.
    local last, right, bottom = nil, 10, 34
    for _, key in ipairs(legend.promptFramesAddOrder) do
        local prompt = legend.promptFrames[key]
        if prompt:IsShown() then
            local _, _, _, x, y = prompt:GetPoint(1)
            right = math.max(right, x + prompt:GetWidth() + 10)
            bottom = math.max(bottom, -y + 34)
            last = prompt
        end
    end
    local width = legend.wrapAroundRowWidth and container:GetWidth() or right
    local height = bottom
    if visible then
        local x, y = 10, -10
        if last then
            local _, _, _, lastX, lastY = last:GetPoint(1)
            x, y = lastX + last:GetWidth() + 15, lastY
        end
        if legend.wrapAroundRowWidth and x + hint:GetWidth() + 10 > width then
            x, y = 10, y - 35
        end
        if not legend.wrapAroundRowWidth then width = x + hint:GetWidth() + 10 end
        height = math.max(height, -y + 34)
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
        local atlas = InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(GAMEPAD_STICK_RIGHT_PRESS)
        if atlas then hint.Icon:SetAtlas(atlas) end
        hint:SetAlpha(enabled and 1 or 0.4)
    end
    container:SetSize(width, height)
    legend:SetHeight(height)
    if not legend.wrapAroundRowWidth then
        legend:SetWidth(width + (legend.modifierFrame and legend.modifierFrame:GetWidth() or 0))
    end
    if legend.modifierFrame then legend.modifierFrame:SetHeight(height) end
    hint:SetShown(visible)
end

local function Refresh()
    if not owner and not InCombatLockdown() then
        owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        owner:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then self:ClearBindings() end
        ]])
        RegisterStateDriver(owner, "combat", "[combat] combat; peace")
        button = CreateFrame("Button", "ForeverTweaksBagCleanup", UIParent)
        button:EnableMouse(false)
        button:RegisterForClicks("AnyDown")
        button:SetScript("OnClick", function()
            if CanCleanUp(GetFooter()) then C_Container.SortBags() end
        end)
    end
    local footer = GetFooter()
    local focused = InventoryHasFocus(footer)
    local enabled = CanCleanUp(footer)
    local legend = footer and footer.inputLegend
    if hintLegend and hintLegend ~= legend then RefreshHint(hintLegend, false, false) end
    if legend then RefreshHint(legend, focused, enabled) end
    if not owner or InCombatLockdown() then return end
    if enabled then
        if GetBindingAction(KEY, true) ~= CLICK then
            owner:Execute([[self:SetBindingClick(true, "PADRSTICK", "ForeverTweaksBagCleanup", "LeftButton")]])
        end
    else
        owner:Execute([[self:ClearBindings()]])
    end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", Refresh)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 or not IsLoggedIn() then return end
    elapsed = 0
    Refresh()
end)
