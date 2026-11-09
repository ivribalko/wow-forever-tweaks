-- Observes inventory More and draws an independent secure Disenchant row above it.
local DISENCHANT = 13262
local driver = CreateFrame("Frame")
local action, context, icon, label

local function KnowsDisenchant()
    return C_SpellBook.IsSpellKnown(DISENCHANT)
end

local function IsInventoryButton(button)
    if not button or not button.GetBagID or not button.GetID then return false end
    local parent = button:GetParent()
    while parent do
        if parent == ContainerFrameCombinedBags then return true end
        parent = parent:GetParent()
    end
    return false
end

local function GetInventoryMenu()
    if not Menu or not ContainerFrameCombinedBags or not ContainerFrameCombinedBags:IsShown() then return end
    local menu = Menu.GetManager():GetOpenMenu()
    if not menu or not menu:IsShown() or not IsInventoryButton(menu:GetOwnerRegion()) then return end
    for _, tag in ipairs(Menu.GetOpenMenuTags()) do
        if tag == "MORE_CONTEXT_ACTIONS" then return menu end
    end
end

local function ItemGUID(bag, slot)
    return C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

local function IsDisenchantableItem(current)
    if not current or not current.guid then return false end
    local info = C_Container.GetContainerItemInfo(current.bag, current.slot)
    if not info or ItemGUID(current.bag, current.slot) ~= current.guid then return false end
    -- The server decides exact item eligibility and required profession skill.
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    return info.quality and info.quality >= Enum.ItemQuality.Uncommon
        and info.quality <= Enum.ItemQuality.Epic
        and (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
end

local function CanDisenchant(current)
    if InCombatLockdown() or not KnowsDisenchant() or GetCursorInfo()
        or SpellIsTargeting() or not current or current.used
        or not IsDisenchantableItem(current) then return false end
    local info = C_Container.GetContainerItemInfo(current.bag, current.slot)
    return info and not info.isLocked
end

local function MenuHasFocus(menu)
    if not menu or GetCurrentKeyBoardFocus() then return false end
    -- Menu footer bindings are not guaranteed to be the top binding set.
    -- The native focus manager identifies which panel actually owns input.
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    return manager and manager.isUIFocused and manager.focusedFrame == menu
        and GetInventoryMenu() == menu
end

-- BackdropTemplate owns OnLoad, so use the global secure-handler API rather
-- than methods normally installed by SecureHandler_OnLoad.
local function ClearAction()
    SecureHandlerExecute(action, [[self:ClearBindings()]])
    action:SetAttribute("type", nil)
    action:SetAttribute("target-bag", nil)
    action:SetAttribute("target-slot", nil)
end

local function Initialize()
    action = CreateFrame("Button", "ForeverTweaksDisenchant", UIParent,
        "SecureActionButtonTemplate,SecureHandlerStateTemplate,BackdropTemplate")
    -- An outside mouse-down dismisses native menus. Act on that press before
    -- the next visual refresh hides this row, rather than waiting for release.
    action:RegisterForClicks("AnyDown")
    action:SetAttribute("useOnKeyDown", true)
    action:SetAttribute("spell", DISENCHANT)
    action:SetHeight(32)
    action:SetClampedToScreen(true)
    action:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    action:SetBackdropColor(0, 0, 0, 0.95)
    action:SetBackdropBorderColor(1, 0.82, 0)
    action:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    icon = action:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", 6, 0)
    label = action:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    label:SetText(C_Spell.GetSpellName(DISENCHANT))
    action:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then
            self:ClearBindings()
            self:SetAttribute("type", nil)
            self:SetAttribute("target-bag", nil)
            self:SetAttribute("target-slot", nil)
            self:Hide()
        end
    ]])
    RegisterStateDriver(action, "combat", "[combat] combat; peace")
    action:SetScript("PreClick", function(self, button)
        self.activated = nil
        if InCombatLockdown() then return end
        local menu = GetInventoryMenu()
        local gamepadClick = button == "Gamepad" and context and menu == context.menu and MenuHasFocus(menu)
        -- A mouse-down may already have dismissed the native menu in this event.
        -- Accept only the still-visible row under the pointer, with no replacement
        -- menu, and revalidate the exact captured item before casting.
        local mouseClick = button == "LeftButton" and self:IsShown() and self:IsMouseOver()
            and context and (menu == context.menu or not Menu.GetManager():GetOpenMenu())
        if (gamepadClick or mouseClick) and CanDisenchant(context) then
            self:SetAttribute("type", "spell")
            self:SetAttribute("target-bag", context.bag)
            self:SetAttribute("target-slot", context.slot)
            self.activated = context
        else
            ClearAction()
        end
    end)
    action:SetScript("PostClick", function(self)
        local activated = self.activated
        self.activated = nil
        if not activated then return end
        activated.used = true
        if not InCombatLockdown() then
            ClearAction()
            self:Hide()
        end
        -- Native dismissal and focus restoration stay entirely native. Square
        -- leaves More open; the user can close it with the normal Back action.
    end)
    action:Hide()
end

local function Refresh()
    if InCombatLockdown() then return end
    if not action then Initialize() end
    local menu = KnowsDisenchant() and GetInventoryMenu()
    if not menu then
        context = nil
        if action:IsShown() or action:GetAttribute("type") then ClearAction(); action:Hide() end
        return
    end
    local owner = menu:GetOwnerRegion()
    if not context or context.menu ~= menu or context.owner ~= owner then
        local bag, slot = owner:GetBagID(), owner:GetID()
        context = { menu = menu, owner = owner, bag = bag, slot = slot, guid = ItemGUID(bag, slot) }
    end
    if context.used or not IsDisenchantableItem(context) then
        ClearAction()
        action:Hide()
        return
    end
    local left, bottom, width, height = menu:GetRect()
    if not left or not bottom or not width or not height then ClearAction(); action:Hide(); return end
    local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
    action:SetScale(1)
    action:SetWidth(math.max(width * scale, label:GetStringWidth() + 47))
    action:ClearAllPoints()
    -- Numeric geometry only: no native parent, anchor, callback, or menu entry.
    action:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, (bottom + height) * scale + 4)
    -- Keep the standalone row above fullscreen inventory chrome as well as the
    -- menu. Do not inherit the menu's potentially scaled presentation layer.
    action:SetFrameStrata("TOOLTIP")
    action:SetFrameLevel(math.max(10000, menu:GetFrameLevel() + 30))
    local atlas = InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(GAMEPAD_FACE_LEFT)
    if atlas then icon:SetAtlas(atlas) end
    local enabled = CanDisenchant(context)
    action:SetAlpha(enabled and 1 or 0.4)
    action:Show()
    if enabled then
        action:SetAttribute("type", "spell")
        action:SetAttribute("target-bag", context.bag)
        action:SetAttribute("target-slot", context.slot)
        if MenuHasFocus(menu) then
            SecureHandlerExecute(action, [[self:SetBindingClick(true, "PAD3", "ForeverTweaksDisenchant", "Gamepad")]])
        else
            SecureHandlerExecute(action, [[self:ClearBindings()]])
        end
    else
        ClearAction()
    end
end

--@alpha@
-- Keep only changing visibility gates; never save item identities or native tables.
local diagnosticElapsed, diagnosticState = 0, nil
local function CaptureVisibility()
    local menu = Menu and Menu.GetManager():GetOpenMenu()
    local owner = menu and menu:GetOwnerRegion()
    local bags = ContainerFrameCombinedBags
    local tags = Menu and Menu.GetOpenMenuTags() or {}
    local state = table.concat({
        "known=" .. tostring(KnowsDisenchant()),
        "combat=" .. tostring(InCombatLockdown()),
        "bags=" .. tostring(bags and bags:IsShown() or false),
        "menu=" .. tostring(menu and menu:IsShown() or false),
        "tags=" .. table.concat(tags, ","),
        "ownerBagAPI=" .. tostring(owner and type(owner.GetBagID) == "function" or false),
        "inventoryOwner=" .. tostring(IsInventoryButton(owner)),
        "detected=" .. tostring(GetInventoryMenu() ~= nil),
        "focused=" .. tostring(MenuHasFocus(menu) or false),
        "row=" .. tostring(action and action:IsShown() or false),
        "visible=" .. tostring(action and action:IsVisible() or false),
        "alpha=" .. tostring(action and action:GetEffectiveAlpha() or 0),
        "rowX=" .. tostring(action and action:GetLeft()),
        "rowY=" .. tostring(action and action:GetBottom()),
        "used=" .. tostring(context and context.used or false),
        "eligible=" .. tostring(CanDisenchant(context) or false),
        "square=" .. tostring(GetBindingAction("PAD3", true)),
    }, "; ")
    if state == diagnosticState then return end
    diagnosticState = state
    if type(ForeverTweaksDiagnostics) ~= "table" then ForeverTweaksDiagnostics = {} end
    local records = ForeverTweaksDiagnostics.disenchantVisibility
    if type(records) ~= "table" then
        records = {}
        ForeverTweaksDiagnostics.disenchantVisibility = records
    end
    records[#records + 1] = { elapsed = GetTime(), state = state }
    while #records > 12 do table.remove(records, 1) end
end
--@end-alpha@

driver:SetScript("OnUpdate", function(self, elapsed)
    if IsLoggedIn() then Refresh() end
    --@alpha@
    diagnosticElapsed = diagnosticElapsed + elapsed
    if IsLoggedIn() and diagnosticElapsed >= 0.2 then
        diagnosticElapsed = 0
        pcall(CaptureVisibility)
    end
    --@end-alpha@
end)
