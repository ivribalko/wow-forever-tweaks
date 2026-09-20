-- Run from the repository root with a Lua interpreter.
local addon = {}
assert(loadfile("MacroRanks.lua"))("ForeverTweaks", addon)
Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 100, MAX_CHARACTER_MACROS = 18 } }
C_Item = { GetItemInfo = function(name)
    if name == "Item(Rank 1)" then return name end
end }
SLASH_CAST1, SLASH_CAST2 = "/cast", "/spellalias"
local macros, edits = {}, 0
function GetNumMacros() return 1, 1 end
function GetMacroInfo(index)
    local macro = macros[index]
    if macro then return macro.name, macro.icon, macro.body end
end
function EditMacro(index, name, icon, body)
    local macro = assert(macros[index])
    macro.name, macro.icon, macro.body = name or macro.name, icon or macro.icon, body or macro.body
    edits = edits + 1
    return index
end
local replacements = { ["spell(rank 1)"] = "Spell", ["spell(rank 2)"] = "Spell", ["item(rank 1)"] = "Item" }
local cases = {
    { "/cast Spell(Rank 1)", "/cast Spell" },
    { "/cast Spell (Rank 2)  ", "/cast Spell  " },
    { "/cast [@focus,help][@player] !Spell(Rank 1); [harm] Spell(Rank 2)", "/cast [@focus,help][@player] !Spell; [harm] Spell" },
    { "/castsequence [@target,harm] reset=target/combat Spell(Rank 1), Spell(Rank 2), null", "/castsequence [@target,harm] reset=target/combat Spell, Spell, null" },
    { "/castrandom Spell(Rank 1),Spell(Rank 2)", "/castrandom Spell,Spell" },
    { "/use [help] Spell(Rank 1); 13", "/use [help] Spell; 13" },
    { "/spellalias Spell(Rank 1)", "/spellalias Spell" },
    { "#showtooltip Spell(Rank 1)\r\n/cast Spell(Rank 1)\n/say Spell(Rank 1)", "#showtooltip Spell\r\n/cast Spell\n/say Spell(Rank 1)" },
    { "/cast Spell\n/run print('Spell(Rank 1)')" },
    { "/use Item(Rank 1)\n/use 13\n/cast Unknown(Rank 1)" },
    { "/cast [known:Spell(Rank 1)] Spell(Rank 1)", "/cast [known:Spell(Rank 1)] Spell" },
    { "/cast Other Spell(Rank 1)" },
}
for index, case in ipairs(cases) do
    macros = {
        [1] = { name = "Custom", icon = 123, body = case[1] },
        [101] = { name = "Custom character", icon = 456, body = case[1] },
    }
    addon.UpgradeCustomMacroRanks(replacements, function() return false end)
    for _, id in ipairs({ 1, 101 }) do
        assert(macros[id].body == (case[2] or case[1]), "case " .. index .. ": " .. macros[id].body)
    end
    assert(macros[1].name == "Custom" and macros[1].icon == 123)
    local before = edits
    addon.UpgradeCustomMacroRanks(replacements, function() return false end)
    assert(edits == before, "repeat pass must not edit")
end

local events, pending, actions, cursor, combat = nil, nil, {}, nil, false
function CreateFrame()
    events = { RegisterEvent = function() end, SetScript = function(self, _, callback) self.callback = callback end }
    return events
end
C_Timer = { After = function(_, callback) pending = callback end }
function InCombatLockdown() return combat end
function GetCursorInfo() if cursor then return cursor.kind, cursor.id end end
function ClearCursor() cursor = nil end
function UnitHasVehicleUI() return false end
local function No() return false end
C_ActionBar = { HasOverrideActionBar = No, HasVehicleActionBar = No, IsPossessBarVisible = No,
    HasTempShapeshiftActionBar = No, IsHarmfulAction = No }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
    GetSpellBookItemInfo = function(slot) return { itemType = 1, spellID = slot, name = "Spell" } end,
    IsSpellBookItemLowRank = function(slot) return slot == 1 end,
}
C_Spell = {
    GetSpellSubtext = function(id) return "Rank " .. id end,
    GetSpellInfo = function() return { name = "Spell", iconID = 789 } end,
    PickupSpell = function(id) cursor = { kind = "spell", id = id } end,
}
function GetActionInfo(slot)
    local action = actions[slot]
    if action then return action.kind, action.id end
end
function PlaceAction(slot) actions[slot] = cursor end
SlashCmdList = {}
local original = "#showtooltip Spell(Rank 1)\n/startattack [@target,combat,harm,nodead]\n/cast Spell(Rank 1)"
macros = {
    [1] = { name = "Custom", icon = 123, body = "/cast Spell(Rank 2)" },
    [101] = { name = "+", icon = 123, body = original },
}
ForeverTweaksAttackMacros = { enabled = false, macros = { ["FT 1"] = { spellID = 1, body = original } } }
actions[1] = { kind = "spell", id = 1 }
actions[2] = { kind = "macro", id = 101 }
assert(loadfile("AttackMacros.lua"))("ForeverTweaks", addon)
events.callback(events, "PLAYER_LOGIN")
combat = true
pending()
assert(macros[101].body == original and actions[1].id == 1, "combat guard")
combat = false
cursor = { kind = "item", id = 7 }
events.callback(events, "CURSOR_CHANGED")
pending()
assert(macros[101].body == original and cursor.id == 7, "occupied cursor guard")
cursor = nil
events.callback(events, "CURSOR_CHANGED")
pending()
assert(macros[1].body == "/cast Spell", "custom highest rank must become rankless")
assert(macros[101].body == "#showtooltip Spell\n/startattack [@target,combat,harm,nodead]\n/cast Spell", "owned migration")
assert(ForeverTweaksAttackMacros.macros["FT 1"].body == macros[101].body, "ownership body")
assert(ForeverTweaksAttackMacros.macros["FT 1"].spellID == 2, "ownership rank")
assert(actions[1].id == 2 and actions[2].kind == "spell" and actions[2].id == 2, "highest-rank actions and restoration")
print("Passed 12 macro cases, idempotence, owned migration, action upgrades, restoration, combat and cursor guards.")
