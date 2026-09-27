-- Upgrade spell ranks and convert harmful actions outside combat.
local _, addon = ...
local events = CreateFrame("Frame")
local state, queued, working, warned

local function ActionSlots()
    local slots = {}
    -- Classic's ten persistent keyboard pages; temporary override bars are excluded.
    for slot = 1, 120 do slots[#slots + 1] = slot end
    local constants = Constants and Constants.GamepadActionBarConstants
    local binding = GamepadActionBarBindingUtil
    if constants and binding then
        for page = 1, constants.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT do
            for button = 1, constants.NUM_PAGEABLE_SLOTS_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT_STANDARD_PAGE do
                local slot = binding.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(page, button)
                if slot then slots[#slots + 1] = slot end
            end
        end
    end
    -- Stance storage is separate from the three standard controller pages.
    if C_GamepadUI and constants then
        local slot = C_GamepadUI.GetFirstGamepadActionBarStorageSlotIndexForActiveStance()
        if slot then
            for offset = 0, constants.NUM_SLOTS_PER_GAMEPAD_ACTION_BAR - 1 do
                if C_GamepadUI.IsValidGamepadActionStorageSlotIndex(slot + offset) then
                    slots[#slots + 1] = slot + offset
                end
            end
        end
    end
    return slots
end

-- The client may append a final newline when storing macro text.
local function NormalizeBody(body)
    return body and body:gsub("\r\n", "\n"):gsub("\n+$", "")
end

local function OwnedMacro(index)
    if index <= Constants.MacroConsts.MAX_ACCOUNT_MACROS then return end
    local name, _, body = GetMacroInfo(index)
    for key, record in pairs(state.macros) do
        if (name == "+" or name == key) and NormalizeBody(record.body) == NormalizeBody(body) then return record end
    end
end

local function RenameOwnedMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    -- Restart the search for each record because renaming can reorder macro indices.
    for key, record in pairs(state.macros) do
        for index = base + 1, base + count do
            local name, _, body = GetMacroInfo(index)
            if name == key and NormalizeBody(body) == NormalizeBody(record.body) then
                EditMacro(index, "+")
                break
            end
        end
    end
end

-- Use Blizzard's rank classification, without parsing localized rank text.
local function SpellUpgrades()
    local upgrades, rankless = {}, {}
    local bank = Enum.SpellBookSpellBank.Player
    for lineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if line then
            local highest, lower = {}, {}
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if info and info.itemType == Enum.SpellBookItemType.Spell
                    and info.spellID and not info.isPassive and not info.isOffSpec then
                    local rank = C_Spell.GetSpellSubtext(info.spellID)
                    if rank and rank ~= "" then
                        rankless[(info.name .. "(" .. rank .. ")"):lower()] = info.name
                    end
                    if C_SpellBook.IsSpellBookItemLowRank(slot, bank) then
                        lower[info.spellID] = info.name
                    elseif highest[info.name] == nil then
                        highest[info.name] = info.spellID
                    elseif highest[info.name] ~= info.spellID then
                        -- Ambiguous same-name abilities are left alone.
                        highest[info.name] = false
                    end
                end
            end
            for spellID, name in pairs(lower) do
                upgrades[spellID] = highest[name] or nil
            end
        end
    end
    return upgrades, rankless
end

local function MacroContents(spellID)
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then return end
    local spell = info.name
    local body = "#showtooltip " .. spell .. "\n/startattack [@target,combat,harm,nodead]\n/cast " .. spell
    if #body > 255 then return end
    return body, info.iconID
end

-- Recover generated entries whose old spell-ID ownership was lost or overwritten.
-- Only the exact generated commands and generated names qualify.
local function RecoverOwnedMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    for index = base + 1, base + count do
        local name, _, body = GetMacroInfo(index)
        body = NormalizeBody(body)
        if not OwnedMacro(index) and name and (name == "+" or name:match("^FT %d+$")) then
            local spell = body and body:match("^#showtooltip ([^\n]+)\n")
            local info = spell and C_Spell.GetSpellInfo(spell)
            if info and MacroContents(info.spellID) == body then
                local key = name ~= "+" and name or "recovered:" .. body
                state.macros[key] = { spellID = info.spellID, body = body }
            end
        end
    end
end

-- Include inactive controller stance storage when redirecting duplicate references.
local function CleanupSlots()
    local slots = {}
    local first = C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()
    for slot = 1, (first and first - 1 or 120) do slots[#slots + 1] = slot end
    if first then
        local slot = first
        while C_GamepadUI.IsValidGamepadActionStorageSlotIndex(slot) do
            slots[#slots + 1] = slot
            slot = slot + 1
        end
    end
    return slots
end

local function ConsolidateOwnedMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    local keepers, duplicates = {}, {}
    for index = base + 1, base + count do
        local record = OwnedMacro(index)
        if record then
            local body = NormalizeBody(record.body)
            if keepers[body] then
                duplicates[#duplicates + 1] = { index = index, keeper = keepers[body] }
            else
                keepers[body] = index
            end
        end
    end
    if #duplicates == 0 then return end
    local slots = CleanupSlots()
    -- Delete descending indices: every keeper is lower than its duplicate and
    -- earlier deletions cannot invalidate the remaining indices.
    for i = #duplicates, 1, -1 do
        local duplicate = duplicates[i]
        local safe = true
        for _, slot in ipairs(slots) do
            local kind, id = GetActionInfo(slot)
            if kind == "macro" and id == duplicate.index then
                PickupMacro(duplicate.keeper)
                local cursorKind, cursorID = GetCursorInfo()
                if cursorKind == "macro" and cursorID == duplicate.keeper then PlaceAction(slot) end
                ClearCursor()
                kind, id = GetActionInfo(slot)
                if kind ~= "macro" or id ~= duplicate.keeper then safe = false end
            end
        end
        -- A rejected placement leaves the duplicate intact for a later retry.
        if safe then DeleteMacro(duplicate.index) end
    end
end

-- Helpful spells do not need attack macros; restore every stored bar reference
-- before reclaiming the generated macro's slot.
local function RestoreHelpfulMacros(upgrades)
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    local slots
    for index = base + count, base + 1, -1 do
        local record = OwnedMacro(index)
        local spellID = record and (upgrades[record.spellID] or record.spellID)
        if spellID and C_Spell.IsSpellHelpful(spellID) then
            slots = slots or CleanupSlots()
            local safe = true
            for _, slot in ipairs(slots) do
                local kind, id = GetActionInfo(slot)
                if kind == "macro" and id == index then
                    C_Spell.PickupSpell(spellID)
                    local cursorKind, _, _, cursorSpellID = GetCursorInfo()
                    if cursorKind == "spell" and cursorSpellID == spellID then PlaceAction(slot) end
                    ClearCursor()
                    kind, id = GetActionInfo(slot)
                    if kind ~= "spell" or id ~= spellID then safe = false end
                end
            end
            if safe then DeleteMacro(index) end
        end
    end
end

local function UpgradeOwnedMacros(upgrades)
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    for _, record in pairs(state.macros) do
        local spellID = upgrades[record.spellID] or record.spellID
        local body, icon = MacroContents(spellID)
        if body and (record.body ~= body or record.spellID ~= spellID) then
            local changed = false
            for index = base + 1, base + count do
                if OwnedMacro(index) == record then
                    EditMacro(index, nil, icon, body)
                    changed = true
                end
            end
            if changed then
                record.spellID, record.body = spellID, body
            end
        end
    end
end

local function EnsureMacro(spellID)
    local body, icon = MacroContents(spellID)
    if not body then return end
    -- Names are shared; resolve each spell by its saved body, never by name alone.
    local key = "FT " .. spellID
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, count = GetNumMacros()
    for index = base + 1, base + count do
        local record = OwnedMacro(index)
        if record and NormalizeBody(record.body) == body then return index end
    end
    local limit = Constants.MacroConsts.MAX_CHARACTER_MACROS
    if count >= limit then
        if not warned then
            print("Forever Tweaks: Free character macro slots to convert more attack abilities.")
            warned = true
        end
        return
    end
    local index = CreateMacro("+", icon, body, true)
    if index then
        state.macros[key] = { spellID = spellID, body = body }
        return index
    end
end

local function Synchronize()
    if not state or working or InCombatLockdown() or GetCursorInfo()
        or UnitHasVehicleUI("player") or C_ActionBar.HasOverrideActionBar()
        or C_ActionBar.HasVehicleActionBar() or C_ActionBar.IsPossessBarVisible()
        or C_ActionBar.HasTempShapeshiftActionBar() then return end
    working = true
    RecoverOwnedMacros()
    RenameOwnedMacros()
    local upgrades, rankless = SpellUpgrades()
    UpgradeOwnedMacros(upgrades)
    RestoreHelpfulMacros(upgrades)
    ConsolidateOwnedMacros()
    addon.UpgradeCustomMacroRanks(rankless, OwnedMacro)
    for _, slot in ipairs(ActionSlots()) do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and upgrades[id] then
            C_Spell.PickupSpell(upgrades[id])
            if GetCursorInfo() == "spell" then PlaceAction(slot) end
            ClearCursor()
            kind, id = GetActionInfo(slot)
        end
        if state.enabled and kind == "spell" and C_ActionBar.IsHarmfulAction(slot, true)
            and not C_Spell.IsSpellHelpful(id)
            and not C_Spell.IsAutoAttackSpell(id) and not C_Spell.IsAutoRepeatSpell(id) then
            local index = EnsureMacro(id)
            if index then
                PickupMacro(index)
                local cursorKind, cursorID = GetCursorInfo()
                if cursorKind == "macro" and cursorID == index then PlaceAction(slot) end
                ClearCursor()
            end
        elseif not state.enabled and kind == "macro" then
            local record = OwnedMacro(id)
            if record then
                C_Spell.PickupSpell(record.spellID)
                if GetCursorInfo() == "spell" then PlaceAction(slot) end
                ClearCursor()
            end
        end
    end
    working = false
end

local function Schedule()
    if queued or working or not state then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        Synchronize()
    end)
end

SLASH_FOREVERTWEAKSATTACK1 = "/ftattack"
SlashCmdList.FOREVERTWEAKSATTACK = function(message)
    if not state then return end
    local command = message:lower():match("^%s*(.-)%s*$")
    if command == "restore" then
        state.enabled = false
        print("Forever Tweaks: Attack macro conversion disabled; spells restore at their highest learned rank when out of combat with an empty cursor.")
    elseif command == "on" then
        state.enabled = true
        warned = false
        print("Forever Tweaks: Attack macro conversion enabled.")
    else
        print("Forever Tweaks: /ftattack on | /ftattack restore")
        return
    end
    Schedule()
end

for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "SPELLS_CHANGED", "CURSOR_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_POSSESS_BAR", "ADDON_LOADED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ForeverTweaksAttackMacros = ForeverTweaksAttackMacros or { enabled = true, macros = {} }
        state = ForeverTweaksAttackMacros
    elseif event == "UPDATE_MACROS" and not working then
        warned = false
    end
    Schedule()
end)
