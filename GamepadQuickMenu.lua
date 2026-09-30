-- Provides a character-specific item/spell wheel at the unused Share fallback.
local driver = CreateFrame("Frame")
local owner, wheel, opener, confirm, cancel, editor
local slots, selected, editing, initialized = {}, nil, false, false
local fallbackBound, listening = false, false
local pendingEntry, bindPrompt, editKey
local ApplyWheelBindings, RefreshBindPrompt
local SHARE = "PADBACK"
local OPEN_BINDING = "CLICK ForeverTweaksQuickMenuOpen:LeftButton"
local RefreshBindings, RefreshSlots, SelectSlot, OpenWheel

local function ClearFallback()
    if fallbackBound then
        ClearOverrideBindings(owner)
        fallbackBound = false
    end
end

local function SetStickListening(enable)
    if not InCombatLockdown() and listening ~= enable then
        wheel:EnableGamePadStick(enable)
        listening = enable
    end
end

local function Notice(message)
    print("|cffffd100Forever Tweaks:|r " .. message)
end

local function NativeUIAvailable()
    return GamepadMode and GamepadMode.FrameControlsManager
        and GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
        and InputUtil and InputUtil.IsGamepadUIEnabled()
end

-- Read native state without replacing focus handlers or joining binding tables.
local function WorldIsClear()
    return NativeUIAvailable()
        and GamepadMode.FrameControlsManager:GetShownFrameCount() == 0
        and not GamepadMode.FrameControlsManager.isUIFocused
        and GamepadSharedUtility.InputBindingManager:IsOnlyCoreBindingSetActive()
        and not (GamepadRadial and GamepadRadial:IsShown())
        and not (GamepadHudMode and GamepadHudMode:IsShown())
        and not (GameMenuFrame and GameMenuFrame:IsShown())
        and not GetCurrentKeyBoardFocus()
        and not InCinematic() and not IsInCinematicScene()
end

-- Read the selection already prepared by Blizzard's item/spell Bind action.
-- Moving an existing bar action is deliberately excluded: that mode owns an
-- emptied source slot and must finish through Blizzard's move/undo workflow.
local function GetNativeBindEntry()
    local source = GamepadActionBarEditFrame
    if not source or not source:IsShown() or source.activeMode ~= "BIND_ACTION"
        or not source.pickupParams or not NativeUIAvailable()
        or GamepadMode.FrameControlsManager:GetActiveFrame() ~= source
        or (GamepadRadial and GamepadRadial:IsShown()) then return end
    local params = source.pickupParams
    local kind, id
    if source.pickupFunc == C_Item.PickupItem and source.displayedActionType == "ITEM" then
        kind, id = "item", params[1]
    elseif source.pickupFunc == C_Spell.PickupSpell and source.displayedActionType == "SPELL" then
        kind, id = "spell", params[1]
    elseif source.pickupFunc == C_SpellBook.PickupSpellBookItem
        and source.displayedActionType == "SPELL" then
        local info = C_SpellBook.GetSpellBookItemInfo(params[1], params[2])
        kind, id = "spell", info and info.spellID
    end
    if type(id) == "number" and id > 0 then return { kind = kind, id = id } end
end

local function GetEntryInfo(entry)
    if not entry then return end
    if entry.kind == "spell" then
        local info = C_Spell.GetSpellInfo(entry.id)
        if info then return info.name, info.iconID end
    elseif entry.kind == "item" then
        return C_Item.GetItemNameByID(entry.id) or "Item " .. entry.id,
            C_Item.GetItemIconByID(entry.id)
    end
end

local function SetAction(button, entry)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    if not entry or editing then return end
    if entry.kind == "spell" then
        -- Rankless spell names follow the highest learned rank.
        local name = GetEntryInfo(entry)
        if name then
            button:SetAttribute("spell", name)
            button:SetAttribute("type1", "spell")
        end
    elseif entry.kind == "item" then
        button:SetAttribute("item", "item:" .. entry.id)
        button:SetAttribute("type1", "item")
    end
end

local function SetFooter()
    if pendingEntry then
        local name = GetEntryInfo(pendingEntry) or "Selected action"
        wheel.Footer:SetText(name .. "\nRight stick: select · X: assign · Square: remove · Circle: back")
    elseif editing then
        wheel.Footer:SetText("Right stick: select · Square: remove · Triangle: done\nCircle / Share: close · Drag an item or spell to add")
    else
        wheel.Footer:SetText("Right stick: select · X: use · Circle / Share: close\nTriangle: edit · Add through the native Bind menu → Share")
    end
end

SelectSlot = function(index)
    if InCombatLockdown() then return end
    selected = index
    SetAction(confirm, index and ForeverTweaksQuickMenu[index])
    wheel.SegmentHighlight:SetShown(index ~= nil)
    if index then
        local angle, x, y = slots[index].art:GetSegmentRotationAndOffset()
        wheel.SegmentHighlight:ClearAllPoints()
        wheel.SegmentHighlight:SetPoint("CENTER", wheel.Background, "CENTER", x, y)
        wheel.SegmentHighlight:SetRotation(angle)
        wheel.SegmentHighlight:SetDesaturated(not ForeverTweaksQuickMenu[index])
    end
end

local function ShowTooltip(button)
    local entry = ForeverTweaksQuickMenu[button:GetID()]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if entry and entry.kind == "spell" then
        GameTooltip:SetSpellByID(entry.id)
    elseif entry and entry.kind == "item" then
        GameTooltip:SetItemByID(entry.id)
    else
        GameTooltip:SetText("Empty slot")
    end
    if editing then
        GameTooltip:AddLine("Drop an item or spell here. Right-click to remove.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function ReceiveEntry(button)
    if InCombatLockdown() then return false end
    local kind, id, _, spellID = GetCursorInfo()
    if not kind then return false end
    if kind == "spell" then id = spellID end
    if (kind ~= "spell" and kind ~= "item") or type(id) ~= "number" then
        Notice("Drag an item from your bags or an ability from your spellbook.")
        return false
    end
    if kind == "spell" and not C_Spell.GetSpellInfo(id) then return false end
    ForeverTweaksQuickMenu[button:GetID()] = { kind = kind, id = id }
    ClearCursor()
    RefreshSlots()
    return true
end

RefreshSlots = function()
    if not wheel or InCombatLockdown() then return end
    for index, button in ipairs(slots) do
        local entry = ForeverTweaksQuickMenu[index]
        local name, icon = GetEntryInfo(entry)
        local art = button.art
        art.SegmentIcon:SetTexture(icon or 134400)
        art.SegmentIcon:SetDesaturated(not entry)
        art.SegmentIcon:SetAlpha(entry and 1 or 0.35)
        art.IconLabel:SetText(name or "Empty")
        art.SegmentDisabled:SetShown(not entry)
        button:SetAttribute("editing", editing)
        SetAction(button, entry)
    end
    SelectSlot(selected)
    SetFooter()
end

RefreshBindings = function()
    if not initialized or InCombatLockdown() then return end
    if not wheel:IsShown() then
        SetStickListening(false)
        wheel:EnableGamePadButton(false)
    end
    local entry = GetNativeBindEntry()
    if wheel:IsShown() and pendingEntry
        and (not entry or entry.kind ~= pendingEntry.kind or entry.id ~= pendingEntry.id) then
        wheel:Hide()
    elseif wheel:IsShown() and not editing and not WorldIsClear() then
        wheel:Hide()
    end
    RefreshBindPrompt(entry)
    local action = GetBindingAction(SHARE, true)
    local shouldBind = not wheel:IsShown() and (entry or (WorldIsClear()
        and (action == "TOGGLEUIFOCUS" or action == OPEN_BINDING)))
    if shouldBind then
        if action ~= OPEN_BINDING then
            SetOverrideBindingClick(owner, true, SHARE, opener:GetName(), "LeftButton")
            fallbackBound = true
        end
    else
        ClearFallback()
    end
end

ApplyWheelBindings = function()
    if InCombatLockdown() then return end
    ClearOverrideBindings(wheel)
    SetOverrideBindingClick(wheel, true, "ESCAPE", cancel:GetName(), "LeftButton")
    -- The edit wheel consumes gamepad input above Blizzard's raw binding
    -- listener. Its X/Square presses must never also rebind an action-bar slot.
    wheel:EnableGamePadButton(editing)
    if not editing then
        SetOverrideBindingClick(wheel, true, "PAD1", confirm:GetName(), "LeftButton")
        for _, key in ipairs({ "PAD2", SHARE }) do
            SetOverrideBindingClick(wheel, true, key, cancel:GetName(), "LeftButton")
        end
        SetOverrideBindingClick(wheel, true, "PAD4", editor:GetName(), "LeftButton")
        for _, key in ipairs({ "PAD3", "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
            "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADRSTICK" }) do
            SetOverrideBindingClick(wheel, true, key, "ForeverTweaksQuickMenuBlock", "LeftButton")
        end
    end
    SetStickListening(true)
end

local function BeginEditing()
    if InCombatLockdown() then return end
    editing = true
    ApplyWheelBindings()
    RefreshSlots()
end

local function AssignPending(index)
    if not index or not pendingEntry or InCombatLockdown() then return end
    local entry = GetNativeBindEntry()
    if not entry or entry.kind ~= pendingEntry.kind or entry.id ~= pendingEntry.id then
        wheel:Hide()
        return
    end
    ForeverTweaksQuickMenu[index] = { kind = entry.kind, id = entry.id }
    Notice((GetEntryInfo(entry) or "Action") .. " assigned to quick-menu slot " .. index .. ".")
    wheel:Hide()
end

OpenWheel = function(editMode, entry)
    if not initialized then return end
    if InCombatLockdown() then
        Notice("The quick menu is available outside combat.")
        return
    end
    if wheel:IsShown() then
        if editMode then BeginEditing() else wheel:Hide() end
        return
    end
    if not editMode and not WorldIsClear() then return end
    editing = editMode or false
    pendingEntry = entry
    -- Stay above the native bind listener while choosing a destination.
    wheel:SetFrameStrata(editing and "FULLSCREEN_DIALOG" or "DIALOG")
    ClearFallback()
    SelectSlot(nil)
    RefreshSlots()
    wheel:Show()
    ApplyWheelBindings()
end

-- An independent native-style prompt avoids inserting addon callbacks into
-- Blizzard's shared footer or binding-stack tables.
RefreshBindPrompt = function(entry)
    local source = GamepadActionBarEditFrame
    if not bindPrompt and source and source.BindingInfoFrame then
        bindPrompt = CreateFrame("Frame", nil, source.BindingInfoFrame, "InputPromptOneIconWithTextTemplate")
        local footer = source.bindingModeFooter and source.bindingModeFooter.inputLegend
        bindPrompt:SetPoint("TOPLEFT", footer or source.BindingInfoFrame, "BOTTOMLEFT", 0, footer and -8 or -50)
        bindPrompt:SetPromptInputIconKey(1, GAMEPAD_MENU_LEFT)
        bindPrompt:SetPromptText("Quick Menu")
        bindPrompt:SetPromptFont("GameFontNormal")
        bindPrompt:SetInputIconSize(1, 20, 20)
        source:HookScript("OnHide", function()
            if pendingEntry and not InCombatLockdown() then wheel:Hide() end
            RefreshBindings()
        end)
        hooksecurefunc(source, "EnterBindingMode", RefreshBindings)
        hooksecurefunc(source, "ExitBindingMode", RefreshBindings)
    end
    if bindPrompt then bindPrompt:SetShown(entry ~= nil and not wheel:IsShown()) end
end

local function Texture(parent, key, atlas, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 0)
    texture:SetAtlas(atlas, true)
    parent[key] = texture
    return texture
end

local function ActionButton(name, parent)
    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    -- Close through a secure post-click even if activation starts combat.
    SecureHandlerWrapScript(button, "OnClick", owner, "return nil, true", [[
        if button == "LeftButton" and self:GetAttribute("type1") then
            self:GetParent():Hide()
        end
    ]])
    return button
end

local function Initialize()
    if initialized or owner or InCombatLockdown() or not GamepadRadialSegmentMixin
        or not NativeUIAvailable() then return end
    if type(ForeverTweaksQuickMenu) ~= "table" then ForeverTweaksQuickMenu = {} end
    for index = 1, 8 do
        local entry = ForeverTweaksQuickMenu[index]
        if type(entry) ~= "table" or (entry.kind ~= "item" and entry.kind ~= "spell")
            or type(entry.id) ~= "number" or entry.id <= 0 or entry.id % 1 ~= 0 then
            ForeverTweaksQuickMenu[index] = nil
        end
    end
    owner = CreateFrame("Frame", "ForeverTweaksQuickMenuOwner", UIParent, "SecureHandlerStateTemplate")
    wheel = CreateFrame("Frame", "ForeverTweaksQuickMenuFrame", UIParent, "SecureHandlerShowHideTemplate")
    wheel:Hide()
    wheel:SetSize(400, 590)
    -- Mirror the native right-hand wheel across the screen center.
    wheel:SetPoint("CENTER", UIParent, "CENTER", -312, 0)
    wheel:SetFrameStrata("DIALOG")
    wheel:SetClampedToScreen(true)
    owner:SetFrameRef("wheel", wheel)
    owner:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then
            self:ClearBindings()
            self:GetFrameRef("wheel"):Hide()
        end
    ]])
    wheel:SetAttribute("_onhide", [[ self:ClearBindings() ]])
    RegisterStateDriver(owner, "combat", "[combat] combat; peace")
    -- Keep this transient wheel out of UISpecialFrames/UIPanelWindows.
    -- Fullscreen menu managers discover those registries and replace geometry;
    -- the wheel instead owns its temporary Escape binding, including edit mode.

    -- Match GamepadRadial.xml's native wheel, header, footer, and eight anchors.
    Texture(wheel, "Background", "gamepad-radial-menu-wheelbg", "OVERLAY", -3):SetPoint("CENTER", 0, 10)
    Texture(wheel, "SegmentHighlight", "gamepad-radial-menu-selected", "OVERLAY", -2):Hide()
    wheel.Header = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    wheel.Header:SetPoint("BOTTOM", wheel, "TOP", 0, 25)
    wheel.Header:SetTextColor(1, 1, 1)
    wheel.Header:SetText("Quick Menu")
    Texture(wheel, "HeaderBackground", "gamepad-radial-menu-toptext", "OVERLAY", -2)
        :SetPoint("TOP", wheel.Header, "BOTTOM", 0, 4)
    local page = Texture(wheel, "PageIndicator", "gamepad-radialgamemenu-cursorbg-neutral")
    page:SetSize(15, 15)
    page:SetPoint("TOP", wheel.Header, "BOTTOM", 0, -24)
    Texture(wheel, "FooterBackground", "gamepad-radial-menu-bottomtext", "OVERLAY", -1)
        :SetPoint("CENTER", wheel, "BOTTOM", 0, -5)
    wheel.Footer = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wheel.Footer:SetPoint("CENTER", wheel.FooterBackground, "CENTER")
    wheel.Footer:SetSize(450, 70)

    confirm = ActionButton("ForeverTweaksQuickMenuConfirm", wheel)
    local anchors = { {150, 0}, {112, 112}, {0, 150}, {-112, 112},
        {-150, 0}, {-112, -112}, {0, -150}, {112, -112} }
    for index, anchor in ipairs(anchors) do
        local art = CreateFrame("Frame", nil, wheel, "GamepadRadialSegmentTemplate")
        art:SetID(index)
        art:SetPoint("CENTER", wheel, "CENTER", anchor[1], anchor[2] + 10)
        local angle, x, y = art:GetSegmentRotationAndOffset()
        art.SegmentDisabled:ClearAllPoints()
        art.SegmentDisabled:SetPoint("CENTER", wheel.Background, "CENTER", x, y)
        art.SegmentDisabled:SetRotation(angle)
        art.SegmentIcon:SetSize(38, 38)
        local iconX, iconY = art:GetIconOffset("number")
        art.SegmentIcon:ClearAllPoints()
        art.SegmentIcon:SetPoint("CENTER", iconX, iconY)
        local labelX, labelY = art:GetIconLabelAnchor()
        art.IconLabel:ClearAllPoints()
        art.IconLabel:SetPoint("CENTER", art.SegmentIcon, "CENTER", labelX, labelY)
        local button = ActionButton("ForeverTweaksQuickMenuSlot" .. index, wheel)
        button:SetID(index)
        button:SetSize(70, 70)
        -- Secure frames must anchor to frames, never texture regions.
        button:SetPoint("CENTER", wheel, "CENTER", anchor[1] + iconX, anchor[2] + iconY + 10)
        button.art = art
        button:SetScript("OnEnter", function(self)
            SelectSlot(self:GetID())
            ShowTooltip(self)
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnReceiveDrag", ReceiveEntry)
        button:SetScript("PreClick", function(self, mouseButton)
            if InCombatLockdown() then return end
            self.receivedCursor = GetCursorInfo() ~= nil
            if editing or self.receivedCursor or mouseButton ~= "LeftButton" then
                self:SetAttribute("type1", nil)
            end
        end)
        button:SetScript("PostClick", function(self, mouseButton)
            if InCombatLockdown() then return end
            if mouseButton == "RightButton" and editing then
                ForeverTweaksQuickMenu[self:GetID()] = nil
            elseif mouseButton == "LeftButton" and pendingEntry then
                AssignPending(self:GetID())
            elseif mouseButton == "LeftButton" and self.receivedCursor then
                ReceiveEntry(self)
            end
            self.receivedCursor = nil
            RefreshSlots()
        end)
        slots[index] = button
    end
    opener = CreateFrame("Button", "ForeverTweaksQuickMenuOpen", UIParent)
    opener:RegisterForClicks("AnyUp")
    opener:SetScript("OnClick", function()
        local entry = GetNativeBindEntry()
        OpenWheel(entry ~= nil, entry)
    end)
    cancel = CreateFrame("Button", "ForeverTweaksQuickMenuClose", wheel)
    cancel:RegisterForClicks("AnyUp")
    cancel:SetScript("OnClick", function() if not InCombatLockdown() then wheel:Hide() end end)
    editor = CreateFrame("Button", "ForeverTweaksQuickMenuEdit", wheel)
    editor:RegisterForClicks("AnyUp")
    editor:SetScript("OnClick", BeginEditing)
    local blocker = CreateFrame("Button", "ForeverTweaksQuickMenuBlock", wheel)
    blocker:RegisterForClicks("AnyDown", "AnyUp")
    wheel:SetScript("OnGamepadStick", function(_, stick, x, y)
        if stick ~= "Camera" or not wheel:IsShown() then return true end
        if not InCombatLockdown() and x * x + y * y > 0.25 then
            local angle = math.deg(math.atan2(y, x))
            SelectSlot(math.floor((angle + 22.5) / 45) % 8 + 1)
        end
        return false
    end)
    wheel:SetScript("OnGamePadButtonDown", function(_, key)
        if not editing or not wheel:IsShown() then return true end
        editKey = key
        return false
    end)
    wheel:SetScript("OnGamePadButtonUp", function(_, key)
        if not editing or not wheel:IsShown() then return true end
        if InCombatLockdown() or editKey ~= key then return false end
        editKey = nil
        -- Finish on release so returning to native bindings cannot replay the
        -- release into a newly restored action or reopen the wheel.
        if key == "PAD1" then
            AssignPending(selected)
        elseif key == "PAD3" and selected then
            ForeverTweaksQuickMenu[selected] = nil
            RefreshSlots()
        elseif key == "PAD2" or key == SHARE then
            wheel:Hide()
        elseif key == "PAD4" and not pendingEntry and WorldIsClear() then
            editing = false
            wheel:SetFrameStrata("DIALOG")
            ApplyWheelBindings()
            RefreshSlots()
        end
        return false
    end)
    wheel:HookScript("OnHide", function()
        SetStickListening(false)
        GameTooltip:Hide()
        pendingEntry, editKey = nil, nil
        if not InCombatLockdown() then
            ClearOverrideBindings(wheel)
            wheel:EnableGamePadButton(false)
        end
    end)
    -- Hooks only refresh our own bindings after native transitions complete.
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if manager then
        for _, method in ipairs({ "FrameShown", "FrameHidden", "SetUIFocusState" }) do
            hooksecurefunc(manager, method, RefreshBindings)
        end
    end
    if GamepadRadial then GamepadRadial:HookScript("OnShow", function()
        if not InCombatLockdown() then wheel:Hide(); RefreshBindings() end
    end) end
    initialized = true
    RefreshSlots()
    RefreshBindings()
end

SLASH_FOREVERTWEAKSQUICKMENU1 = "/ftquick"
SlashCmdList.FOREVERTWEAKSQUICKMENU = function(message)
    Initialize()
    if not initialized then Notice("The quick menu is not ready. Try again outside combat."); return end
    local command = strtrim(message):lower()
    if command == "edit" then OpenWheel(true)
    elseif command == "" then OpenWheel(false)
    else Notice("/ftquick opens the wheel; /ftquick edit lets you drop items or spells and right-click to remove them.") end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("GET_ITEM_INFO_RECEIVED")
driver:RegisterEvent("SPELLS_CHANGED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" or IsLoggedIn() then Initialize() end
    if initialized then RefreshSlots(); RefreshBindings() end
end)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    if not initialized and IsLoggedIn() then Initialize() end
    RefreshBindings()
end)
