-- Provides a character-specific item/spell wheel at the unused Share fallback.
local driver = CreateFrame("Frame")
local owner, wheel, opener, cancel, editor
local slots, selected, editing, initialized = {}, nil, false, false
local fallbackBound, listening = false, false
local pendingEntry, bindPrompt, bindLegend, editKey
local ApplyWheelBindings, RefreshBindPrompt
local SHARE = "PADBACK"
local QUEST_SLOT = 3 -- The top sector in the native radial geometry.
local questEntry
local OPEN_BINDING = "CLICK ForeverTweaksQuickMenuOpen:LeftButton"
local RefreshBindings, RefreshSlots, SelectSlot, OpenWheel

-- Secure paths own visibility, routing, and activation during combat. Lua only
-- paints the selection; secure release samples the physical stick itself.
local COMBAT_REFRESH = [[
    if self:GetAttribute("state-combat") ~= "combat" or self:GetAttribute("refreshing") then return end
    self:SetAttribute("refreshing", true)
    local menu = self:GetFrameRef("wheel")
    local blocked = not IsGamePadEnabled() or not self:GetAttribute("gamepad-ui")
    for i = 1, self:GetAttribute("blocker-count") do
        if self:GetFrameRef("blocker-" .. i):IsVisible() then blocked = true end
    end
    self:SetAttribute("combat-available", not blocked)
    self:ClearBindings()
    if blocked then
        menu:Hide()
    elseif menu:IsShown() then
        menu:SetBindingClick(true, "PAD2", "ForeverTweaksQuickMenuClose", "LeftButton")
        menu:SetBindingClick(true, "PADBACK", "ForeverTweaksQuickMenuOpen", "LeftButton")
        menu:SetBindingClick(true, "ESCAPE", "ForeverTweaksQuickMenuClose", "LeftButton")
        for key in string.gmatch("PAD1 PAD3 PAD4 PADDUP PADDRIGHT PADDDOWN PADDLEFT PADLSHOULDER PADRSHOULDER PADLTRIGGER PADRTRIGGER PADRSTICK", "%S+") do
            menu:SetBindingClick(true, key, "ForeverTweaksQuickMenuBlock", "LeftButton")
        end
    else
        self:SetBindingClick(true, "PADBACK", "ForeverTweaksQuickMenuOpen", "LeftButton")
    end
    self:SetAttribute("refreshing", nil)
]]
local COMBAT_STATE = [[
    local menu = self:GetFrameRef("wheel")
    self:ClearBindings()
    if newstate == "combat" then
        if menu:GetAttribute("editing") then menu:Hide() end
        menu:SetAttribute("editing", nil)
        for i = 1, 8 do
            local slot = self:GetFrameRef("slot-" .. i)
            slot:SetAttribute("type1", slot:GetAttribute("saved-type"))
        end
        self:RunAttribute("combat-refresh")
    else
        menu:Hide()
    end
]]
-- The native state-driver tick samples input securely in and out of combat.
-- Keep the highlight and release action on this same retained selection.
local SAMPLE_SELECTION = [[
    local menu = self:GetFrameRef("wheel")
    if not menu:IsShown() or menu:GetAttribute("editing") then return end
    local state = GetGamePadState()
    local stick = state and state.sticks[self:GetAttribute("camera-stick")]
    if stick and stick.x * stick.x + stick.y * stick.y > 0.25 then
        local index = math.floor((math.deg(math.atan2(stick.y, stick.x)) + 22.5) / 45) % 8 + 1
        if index ~= self:GetAttribute("selected-slot") then
            self:SetAttribute("selected-slot", index)
            self:CallMethod("PaintSelection", index)
        end
    end
]]
local SELECTION_TICK = [[
    if newstate ~= "sample" then return end
    self:RunAttribute("sample-selection")
    -- The native driver compares its result with the current attribute on
    -- each tick. Clearing it schedules another sample without recursion.
    self:SetAttribute("state-selection", nil)
]]
-- Both Share edges use the same secure action button. Only its real release
-- can activate; cancellation or entering edit mode disarms it.
local SHARE_HOLD = [[
    local menu = control:GetFrameRef("wheel")
    self:SetAttribute("type1", nil)
    if down then
        self:SetAttribute("hold-armed", nil)
        self:SetAttribute("bind-press", nil)
        if control:GetAttribute("state-combat") == "combat" then
            control:RunAttribute("combat-refresh")
            if control:GetAttribute("combat-available") then
                self:SetAttribute("hold-armed", true)
                menu:Show()
            end
            return nil, false
        elseif control:GetAttribute("bind-mode") then
            self:SetAttribute("bind-press", true)
            return nil, "open"
        else
            self:SetAttribute("hold-armed", true)
            return nil, "open"
        end
    end
    if self:GetAttribute("bind-press") then
        self:SetAttribute("bind-press", nil)
        return nil, "assign"
    end
    local armed = self:GetAttribute("hold-armed")
    self:SetAttribute("hold-armed", nil)
    if not armed or not menu:IsShown() or menu:GetAttribute("editing") then return nil, false end
    control:RunAttribute("sample-selection")
    local index = control:GetAttribute("selected-slot")
    if index and index >= 1 and index <= 8 then
        local slot = control:GetFrameRef("slot-" .. index)
        self:SetAttribute("spell", slot:GetAttribute("spell"))
        self:SetAttribute("item", slot:GetAttribute("item"))
        self:SetAttribute("macro", slot:GetAttribute("macro"))
        self:SetAttribute("type1", slot:GetAttribute("saved-type"))
    end
    return nil, "close"
]]
local combatBlockers = {}
local function DiscoverCombatBlockers()
    if not initialized or InCombatLockdown() then return end
    owner:SetAttribute("gamepad-ui", InputUtil.IsGamepadUIEnabled())
    -- IM edit boxes remain shown while idle, and chat windows stay visible
    -- after leaving the focus manager. Only the native focus footer reflects
    -- whether chat currently owns the controller, in either chat style.
    local chatOwners = {}
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local chat = _G[name]
        if chat then
            chatOwners[chat] = chat
            if chat.editBox then chatOwners[chat.editBox] = chat end
        end
    end
    local function Watch(panel)
        local chat = panel and chatOwners[panel]
        if chat then panel = chat.footer end
        if not panel or panel == wheel or panel == owner or combatBlockers[panel]
            or not panel.IsForbidden or panel:IsForbidden() then return end
        local proxy = CreateFrame("Frame", nil, panel, "SecureHandlerBaseTemplate")
        combatBlockers[panel] = proxy
        local count = (owner:GetAttribute("blocker-count") or 0) + 1
        owner:SetAttribute("blocker-count", count)
        owner:SetFrameRef("blocker-" .. count, proxy)
        for _, script in ipairs({ "OnShow", "OnHide" }) do
            SecureHandlerWrapScript(proxy, script, owner, [[ control:RunAttribute("combat-refresh") ]])
        end
        proxy:Show()
    end
    for name in pairs(UIPanelWindows or {}) do Watch(_G[name]) end
    for _, name in ipairs(UISpecialFrames or {}) do Watch(_G[name]) end
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    for _, panel in ipairs(manager and manager.shownFrames or {}) do Watch(panel) end
    for _, name in ipairs({ "GamepadRadial", "GamepadHudMode", "GamepadActionBarEditFrame",
        "GameMenuFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
        "CinematicFrame", "MovieFrame" }) do Watch(_G[name]) end
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local chat = _G[name]
        if chat then Watch(chat.footer) end
    end
    for i = 0, 7 do
        if C_GamePad.StickIndexToConfigName(i) == "Camera" then
            owner:SetAttribute("camera-stick", i + 1)
            break
        end
    end
end

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

-- Macro indices shift when other macros are removed. Preserve scope and
-- identity instead of silently executing whatever occupies a saved index.
local function MacroEntry(index)
    local name, _, body = GetMacroInfo(index)
    if not name then return end
    return { kind = "macro", id = index, name = name, body = body,
        character = index > Constants.MacroConsts.MAX_ACCOUNT_MACROS }
end

local function ResolveMacro(entry)
    local accountCount, characterCount = GetNumMacros()
    local base = entry.character and Constants.MacroConsts.MAX_ACCOUNT_MACROS or 0
    local count = entry.character and characterCount or accountCount
    local candidate, matches = nil, 0
    for index = base + 1, base + count do
        local name, _, body = GetMacroInfo(index)
        if name == entry.name then
            if body == entry.body then return index end
            candidate, matches = index, matches + 1
        end
    end
    -- A uniquely named macro can be edited without losing the wheel binding.
    if matches == 1 then return candidate end
end

-- Read the selection already prepared by Blizzard's item/spell/macro Bind action.
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
    if source.pickupFunc == PickupMacro and source.displayedActionType == "MACRO" then
        return MacroEntry(params[1])
    elseif source.pickupFunc == C_Item.PickupItem and source.displayedActionType == "ITEM" then
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

-- The active tracker quest owns the reserved top slot; combat keeps the
-- last configured item and its artwork together until protected edits resume.
local function GetSlotEntry(index)
    if index == QUEST_SLOT then return questEntry end
    return ForeverTweaksQuickMenu[index]
end

local function RefreshQuestEntry()
    questEntry = nil
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if not questID or questID == 0 or C_QuestLog.GetQuestWatchType(questID) == nil then return end
    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex or logIndex == 0 then return end
    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if not link or not icon or (C_QuestLog.IsComplete(questID) and not showWhenComplete) then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then questEntry = { kind = "item", id = itemID, questID = questID, icon = icon } end
end

-- Relocate the old top binding when space permits, otherwise retain it in
-- SavedVariables until another custom slot becomes available.
local function PreserveTopBinding()
    local entry = ForeverTweaksQuickMenu[QUEST_SLOT]
    if not entry then return end
    for index = 1, 8 do
        if index ~= QUEST_SLOT and not ForeverTweaksQuickMenu[index] then
            ForeverTweaksQuickMenu[index] = entry
            ForeverTweaksQuickMenu[QUEST_SLOT] = nil
            return
        end
    end
end

local function GetEntryInfo(entry)
    if not entry then return end
    if entry.kind == "spell" then
        local info = C_Spell.GetSpellInfo(entry.id)
        if info then return info.name, info.iconID end
    elseif entry.kind == "macro" then
        local index = ResolveMacro(entry)
        if index then return GetMacroInfo(index) end
        return (entry.name or "Macro") .. " (unavailable)", 134400
    elseif entry.kind == "item" then
        return C_Item.GetItemNameByID(entry.id) or "Item " .. entry.id,
            entry.icon or C_Item.GetItemIconByID(entry.id)
    end
end

-- Native cooldown widgets render countdowns without addon timer arithmetic.
local function RefreshCooldowns()
    if not wheel or not wheel:IsShown() then return end
    for index, button in ipairs(slots) do
        local entry = GetSlotEntry(index)
        local spell, item
        if entry then
            if entry.kind == "spell" then
                spell = GetEntryInfo(entry) -- Rankless name matches the wheel action.
            elseif entry.kind == "item" then
                item = entry.id
            elseif entry.kind == "macro" then
                local macro = ResolveMacro(entry)
                if macro then
                    spell = GetMacroSpell(macro)
                    if not spell then
                        local _, link = GetMacroItem(macro)
                        item = link
                    end
                end
            end
        end
        local cooldown = button.cooldown
        if entry and entry.questID then
            local logIndex = C_QuestLog.GetLogIndexForQuestID(entry.questID)
            if logIndex and logIndex > 0 then
                local start, duration = GetQuestLogSpecialItemCooldown(logIndex)
                if start then cooldown:SetCooldown(start, duration) else cooldown:Clear() end
            else
                cooldown:Clear()
            end
        elseif spell then
            local duration = C_Spell.GetSpellCooldownDuration(spell)
            if duration then
                -- Keep restricted timing inside the native duration object;
                -- SetCooldown rejects raw secret numbers from addon code.
                cooldown:SetCooldownFromDurationObject(duration, true)
            else
                cooldown:Clear()
            end
        elseif item then
            local start, duration = C_Item.GetItemCooldown(item)
            cooldown:SetCooldown(start, duration)
        else
            cooldown:Clear()
        end
    end
end

local function SetAction(button, entry)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macro", nil)
    button:SetAttribute("saved-type", nil)
    if not entry then return end
    if entry.kind == "spell" then
        -- Rankless spell names follow the highest learned rank.
        local name = GetEntryInfo(entry)
        if name then
            button:SetAttribute("spell", name)
            button:SetAttribute("type1", "spell")
        end
    elseif entry.kind == "macro" then
        local index = ResolveMacro(entry)
        if index then
            button:SetAttribute("macro", index)
            button:SetAttribute("type1", "macro")
        end
    elseif entry.kind == "item" then
        button:SetAttribute("item", "item:" .. entry.id)
        button:SetAttribute("type1", "item")
    end
    button:SetAttribute("saved-type", button:GetAttribute("type1"))
    if editing then button:SetAttribute("type1", nil) end
end

local function SetFooter()
    local combat = InCombatLockdown()
    wheel.EditHint:SetAlpha(combat and 0.4 or ((editing or pendingEntry) and 0 or 1))
    wheel.RemoveHint:SetAlpha(not combat and editing and not pendingEntry and 1 or 0)
    if InCombatLockdown() then
        wheel.Footer:SetText("")
    elseif pendingEntry then
        local name = GetEntryInfo(pendingEntry) or "Selected action"
        wheel.Footer:SetText(name .. "\nHold Share · Aim right stick · Release Share: assign · Circle: back")
    elseif editing then
        wheel.Footer:SetText("")
    else
        wheel.Footer:SetText("")
    end
end

SelectSlot = function(index)
    selected = index
    wheel.SegmentHighlight:SetShown(index ~= nil)
    if index then
        local angle, x, y = slots[index].art:GetSegmentRotationAndOffset()
        wheel.SegmentHighlight:ClearAllPoints()
        wheel.SegmentHighlight:SetPoint("CENTER", wheel.Background, "CENTER", x, y)
        wheel.SegmentHighlight:SetRotation(angle)
        wheel.SegmentHighlight:SetDesaturated(not GetSlotEntry(index))
    end
end

local function ShowTooltip(button)
    local entry = GetSlotEntry(button:GetID())
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if entry and entry.kind == "spell" then
        GameTooltip:SetSpellByID(entry.id)
    elseif entry and entry.kind == "item" then
        GameTooltip:SetItemByID(entry.id)
    elseif entry and entry.kind == "macro" then
        local name = GetEntryInfo(entry)
        GameTooltip:SetText(name)
    else
        GameTooltip:SetText(button:GetID() == QUEST_SLOT and "Quest item" or "Empty slot")
    end
    if button:GetID() == QUEST_SLOT then
        GameTooltip:AddLine("Reserved for the active tracked quest item. Updates outside combat.", 1, 1, 1, true)
    elseif editing then
        GameTooltip:AddLine("Drop an item, spell, or macro here. Right-click to remove.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function ReceiveEntry(button)
    if InCombatLockdown() then return false end
    if button:GetID() == QUEST_SLOT then
        Notice("The top slot is reserved for the active quest item.")
        return false
    end
    local kind, id, _, spellID = GetCursorInfo()
    if not kind then return false end
    if kind == "spell" then id = spellID end
    if (kind ~= "spell" and kind ~= "item" and kind ~= "macro") or type(id) ~= "number" then
        Notice("Drag an item, ability, or macro onto a slot.")
        return false
    end
    if kind == "spell" and not C_Spell.GetSpellInfo(id) then return false end
    ForeverTweaksQuickMenu[button:GetID()] = kind == "macro" and MacroEntry(id) or { kind = kind, id = id }
    ClearCursor()
    RefreshSlots()
    return true
end

RefreshSlots = function()
    if not wheel or InCombatLockdown() then return end
    PreserveTopBinding()
    RefreshQuestEntry()
    for index, button in ipairs(slots) do
        local entry = GetSlotEntry(index)
        local name, icon = GetEntryInfo(entry)
        local art = button.art
        art.SegmentIcon:SetTexture(icon or 134400)
        art.SegmentIcon:SetDesaturated(not entry)
        art.SegmentIcon:SetAlpha(entry and 1 or 0.35)
        art.IconLabel:SetText(name or (index == QUEST_SLOT and "Quest item" or "Empty"))
        art.SegmentDisabled:SetShown(not entry)
        button:SetAttribute("editing", editing)
        SetAction(button, entry)
    end
    SelectSlot(selected)
    SetFooter()
end

RefreshBindings = function()
    if not initialized or InCombatLockdown() then return end
    DiscoverCombatBlockers()
    if not wheel:IsShown() then
        SetStickListening(false)
        wheel:EnableGamePadButton(false)
    end
    local entry = GetNativeBindEntry()
    owner:SetAttribute("bind-mode", entry ~= nil)
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
    wheel:SetAttribute("editing", editing)
    ClearOverrideBindings(wheel)
    SetOverrideBindingClick(wheel, true, "ESCAPE", cancel:GetName(), "LeftButton")
    -- The edit wheel consumes gamepad input above Blizzard's raw binding
    -- listener. Its X/Square presses must never also rebind an action-bar slot.
    wheel:EnableGamePadButton(editing)
    -- Preserve the opener's release route during a native Bind-menu hold.
    -- Raw edit input was enabled after Share down and may miss its release.
    if not editing or pendingEntry then
        SetOverrideBindingClick(wheel, true, SHARE, opener:GetName(), "LeftButton")
    end
    if not editing then
        for _, key in ipairs({ "PAD2" }) do
            SetOverrideBindingClick(wheel, true, key, cancel:GetName(), "LeftButton")
        end
        SetOverrideBindingClick(wheel, true, "PAD4", editor:GetName(), "LeftButton")
        for _, key in ipairs({ "PAD1", "PAD3", "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
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
    if index == QUEST_SLOT then
        Notice("The top slot is reserved for the active quest item.")
        return
    end
    local entry = GetNativeBindEntry()
    if not entry or entry.kind ~= pendingEntry.kind or entry.id ~= pendingEntry.id then
        wheel:Hide()
        return
    end
    ForeverTweaksQuickMenu[index] = entry
    Notice((GetEntryInfo(entry) or "Action") .. " assigned to quick-menu slot " .. index .. ".")
    wheel:Hide()
end

-- A binding hold only assigns; it never activates the destination action.
local function FinishBinding()
    if InCombatLockdown() or not pendingEntry or not wheel:IsShown() then return end
    AssignPending(selected)
    if wheel:IsShown() then wheel:Hide() end
end

OpenWheel = function(editMode, entry)
    if not initialized then return end
    if InCombatLockdown() then
        Notice("Use Share to open the quick menu in combat; editing is available outside combat.")
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

-- Append an independent visual inside the native hint panel. Only layout is
-- extended; native prompted-binding and input-stack tables remain untouched.
local function LayoutBindPrompt()
    if not bindPrompt or not bindPrompt:IsShown() or InCombatLockdown() then return end
    local container = bindLegend.promptContainerFrame
    local last
    for _, key in ipairs(bindLegend.promptFramesAddOrder) do
        local prompt = bindLegend.promptFrames[key]
        if prompt:IsShown() then last = prompt end
    end
    local x, y = 10, -10
    if last then
        local _, _, _, lastX, lastY = last:GetPoint(1)
        x, y = lastX + last:GetWidth() + 15, lastY
    end
    local width = x + bindPrompt:GetWidth() + 10
    if bindLegend.wrapAroundRowWidth then
        if width > container:GetWidth() then
            x, y = 10, y - 35
            local height = -y + 34
            container:SetHeight(height)
            bindLegend:SetHeight(height)
            if bindLegend.modifierFrame then bindLegend.modifierFrame:SetHeight(height) end
        end
    else
        local extra = width - container:GetWidth()
        container:SetWidth(width)
        bindLegend:SetWidth(bindLegend:GetWidth() + extra)
    end
    bindPrompt:ClearAllPoints()
    bindPrompt:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
end

RefreshBindPrompt = function(entry)
    local source = GamepadActionBarEditFrame
    local footer = source and source.bindingModeFooter and source.bindingModeFooter.inputLegend
    if not bindPrompt and footer and footer.promptContainerFrame then
        bindLegend = footer
        bindPrompt = CreateFrame("Frame", nil, footer.promptContainerFrame, "InputPromptOneIconWithTextTemplate")
        bindPrompt:Hide()
        bindPrompt:SetPromptInputIconKey(1, GAMEPAD_MENU_LEFT)
        bindPrompt:SetPromptText("Hold: Quick Menu")
        bindPrompt:SetPromptFont("GameFontNormal")
        bindPrompt:SetInputIconSize(1, 24, 24)
        hooksecurefunc(footer, "ApplyDefaultPromptPositioning", LayoutBindPrompt)
        source:HookScript("OnHide", function()
            if pendingEntry and not InCombatLockdown() then wheel:Hide() end
            RefreshBindings()
        end)
        hooksecurefunc(source, "EnterBindingMode", RefreshBindings)
        hooksecurefunc(source, "ExitBindingMode", RefreshBindings)
    end
    if bindPrompt then
        local visible = entry ~= nil and not wheel:IsShown()
        if bindPrompt:IsShown() ~= visible then
            bindPrompt:SetShown(visible)
            bindLegend:ApplyDefaultPromptPositioning()
        end
    end
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
        if type(entry) ~= "table" or (entry.kind ~= "item" and entry.kind ~= "spell" and entry.kind ~= "macro")
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
    owner:SetAttribute("blocker-count", 0)
    owner:SetAttribute("camera-stick", 2)
    owner.PaintSelection = function(_, index) SelectSlot(index) end
    owner:SetAttribute("sample-selection", SAMPLE_SELECTION)
    owner:SetAttribute("_onstate-selection", SELECTION_TICK)
    owner:SetAttribute("combat-refresh", COMBAT_REFRESH)
    owner:SetAttribute("_onstate-combat", COMBAT_STATE)
    wheel:SetFrameRef("owner", owner)
    wheel:SetAttribute("_onshow", [[
        local owner = self:GetFrameRef("owner")
        owner:SetAttribute("selected-slot", nil)
        owner:CallMethod("PaintSelection")
        owner:RunAttribute("sample-selection")
        if self:GetFrameRef("owner"):GetAttribute("state-combat") == "combat" then
            self:EnableGamePadButton(false)
            self:EnableGamePadStick(true)
            self:GetFrameRef("owner"):RunAttribute("combat-refresh")
        end
    ]])
    wheel:SetAttribute("_onhide", [[
        local opener = self:GetFrameRef("owner"):GetFrameRef("opener")
        if opener then
            opener:SetAttribute("hold-armed", nil)
            opener:SetAttribute("bind-press", nil)
        end
        self:GetFrameRef("owner"):SetAttribute("selected-slot", nil)
        self:ClearBindings()
        self:EnableGamePadButton(false)
        self:EnableGamePadStick(false)
        self:GetFrameRef("owner"):RunAttribute("combat-refresh")
    ]])
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
    local editHint = CreateFrame("Frame", nil, wheel, "InputPromptOneIconWithTextTemplate")
    editHint:SetPoint("CENTER", wheel, "BOTTOM", 0, -5)
    editHint:SetPromptInputIconKey(1, GAMEPAD_FACE_TOP)
    editHint:SetPromptText("Edit")
    editHint:SetPromptFont("GameFontNormal")
    editHint:SetInputIconSize(1, 24, 24)
    wheel.EditHint = editHint
    local removeHint = CreateFrame("Frame", nil, wheel, "InputPromptOneIconWithTextTemplate")
    removeHint:SetPoint("CENTER", wheel, "BOTTOM", 0, -5)
    removeHint:SetPromptInputIconKey(1, GAMEPAD_FACE_LEFT)
    removeHint:SetPromptText("Remove")
    removeHint:SetPromptFont("GameFontNormal")
    removeHint:SetInputIconSize(1, 24, 24)
    removeHint:SetAlpha(0)
    wheel.RemoveHint = removeHint

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
        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:ClearAllPoints()
        cooldown:SetSize(38, 38)
        cooldown:SetPoint("CENTER", button, "CENTER")
        cooldown:EnableMouse(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetHideCountdownNumbers(false)
        cooldown:SetCountdownAbbrevThreshold(0)
        button.cooldown = cooldown
        button:SetScript("OnEnter", function(self)
            if editing then SelectSlot(self:GetID()) end
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
            if mouseButton == "RightButton" and editing and self:GetID() ~= QUEST_SLOT then
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
        owner:SetFrameRef("slot-" .. index, button)
    end
    opener = CreateFrame("Button", "ForeverTweaksQuickMenuOpen", UIParent, "SecureActionButtonTemplate")
    opener:RegisterForClicks("AnyDown", "AnyUp")
    opener:SetAttribute("useOnKeyDown", false)
    owner:SetFrameRef("opener", opener)
    owner.FinishBinding = FinishBinding
    owner.OpenFromShare = function()
        if InCombatLockdown() then return end
        local entry = GetNativeBindEntry()
        OpenWheel(entry ~= nil, entry)
    end
    SecureHandlerWrapScript(opener, "OnClick", owner, SHARE_HOLD, [[
        if message == "open" then
            control:CallMethod("OpenFromShare")
        elseif message == "assign" then
            control:CallMethod("FinishBinding")
        elseif message == "close" then
            control:GetFrameRef("wheel"):Hide()
            self:SetAttribute("type1", nil)
        end
    ]])
    cancel = CreateFrame("Button", "ForeverTweaksQuickMenuClose", wheel, "SecureHandlerClickTemplate")
    cancel:RegisterForClicks("AnyUp")
    cancel:SetScript("OnClick", function() if not InCombatLockdown() then wheel:Hide() end end)
    SecureHandlerWrapScript(cancel, "OnClick", owner, [[
        if control:GetAttribute("state-combat") == "combat" then
            control:GetFrameRef("wheel"):Hide()
            return false
        end
    ]])
    editor = CreateFrame("Button", "ForeverTweaksQuickMenuEdit", wheel)
    editor:RegisterForClicks("AnyUp")
    editor:SetScript("OnClick", BeginEditing)
    local blocker = CreateFrame("Button", "ForeverTweaksQuickMenuBlock", wheel)
    blocker:RegisterForClicks("AnyDown", "AnyUp")
    wheel:SetScript("OnGamepadStick", function(_, stick, x, y)
        if stick ~= "Camera" or not wheel:IsShown() then return true end
        if editing and x * x + y * y > 0.25 then
            local angle = math.deg(math.atan2(y, x))
            SelectSlot(math.floor((angle + 22.5) / 45) % 8 + 1)
        end
        -- Normal selection is painted by the secure sampler in both modes.
        -- Raw stick callbacks only select editing slots and consume camera input.
        return false
    end)
    wheel:SetScript("OnGamePadButtonDown", function(_, key)
        if not editing or not wheel:IsShown() then return true end
        if key == SHARE and pendingEntry then return true end
        editKey = key
        return false
    end)
    wheel:SetScript("OnGamePadButtonUp", function(_, key)
        if not editing or not wheel:IsShown() then return true end
        if InCombatLockdown() then return false end
        -- Let the preserved click binding complete the original Share hold.
        if key == SHARE and pendingEntry then return true end
        if editKey ~= key then return false end
        editKey = nil
        -- Finish on release so returning to native bindings cannot replay the
        -- release into a newly restored action or reopen the wheel.
        if key == "PAD3" and selected and selected ~= QUEST_SLOT and not pendingEntry then
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
    wheel:HookScript("OnShow", function()
        if InCombatLockdown() then editing = false; listening = true end
        SetFooter()
        RefreshCooldowns()
    end)
    wheel:HookScript("OnHide", function()
        SetStickListening(false)
        GameTooltip:Hide()
        pendingEntry, editKey = nil, nil
        listening = false
        if InCombatLockdown() then editing = false end
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
    DiscoverCombatBlockers()
    RegisterStateDriver(owner, "combat", "[combat] combat; peace")
    RegisterStateDriver(owner, "selection", "sample")
    RefreshBindings()
end

SLASH_FOREVERTWEAKSQUICKMENU1 = "/ftquick"
SlashCmdList.FOREVERTWEAKSQUICKMENU = function(message)
    Initialize()
    if not initialized then Notice("The quick menu is not ready. Try again outside combat."); return end
    local command = strtrim(message):lower()
    if command == "edit" then OpenWheel(true)
    elseif command == "" then OpenWheel(false)
    else Notice("/ftquick opens the wheel; /ftquick edit lets you drop items, spells, or macros and right-click to remove them.") end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("GET_ITEM_INFO_RECEIVED")
driver:RegisterEvent("SPELLS_CHANGED")
driver:RegisterEvent("UPDATE_MACROS")
driver:RegisterEvent("SUPER_TRACKING_CHANGED")
driver:RegisterEvent("QUEST_LOG_UPDATE")
driver:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" or IsLoggedIn() then Initialize() end
    if initialized then RefreshSlots(); RefreshBindings(); SetFooter() end
end)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    if not initialized and IsLoggedIn() then Initialize() end
    RefreshBindings()
    RefreshCooldowns()
end)
