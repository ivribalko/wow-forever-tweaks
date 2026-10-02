-- Adds native error suppression to the two supported consume/conjure macros.
local driver = CreateFrame("Frame")
local previousSuppression = "/run UIErrorsFrame:SuppressMessagesThisFrame()\n"
local suppression = "/run ForeverTweaksSuppressFoodErrors()\n"
local restoreTimer, restoreErrors

-- Restore the user's error-event registration on timer expiry and before logout/reload.
local function RestoreErrorHandling()
    if restoreTimer then restoreTimer:Cancel() end
    if restoreErrors then UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end
    restoreTimer, restoreErrors = nil, nil
end

-- Server rejections can arrive after the macro's frame has finished.
function ForeverTweaksSuppressFoodErrors()
    if restoreTimer then
        restoreTimer:Cancel()
    else
        restoreErrors = UIErrorsFrame:IsEventRegistered("UI_ERROR_MESSAGE")
    end
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    restoreTimer = C_Timer.NewTimer(1, RestoreErrorHandling)
end
local recipes = {
    { spell = "Conjure Water", items = { 22018, 8079, 8078, 8077, 3772, 2136, 2288, 5350 } },
    { spell = "Conjure Food", items = { 22895, 8076, 8075, 1487, 1114, 1113, 5349 } },
}
local replacements = {}
for _, recipe in ipairs(recipes) do
    local lines = { "#showtooltip " .. recipe.spell }
    for _, item in ipairs(recipe.items) do lines[#lines + 1] = "/use item:" .. item end
    lines[#lines + 1] = "/cast " .. recipe.spell
    local body = table.concat(lines, "\n")
    replacements[body] = suppression .. body
    replacements[previousSuppression .. body] = suppression .. body
end

local function UpdateMacros()
    if InCombatLockdown() or GetCursorInfo() then return end
    local accountCount, characterCount = GetNumMacros()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local function Update(index)
        local name, _, body = GetMacroInfo(index)
        if not body then return end
        local normalized = body:gsub("\r\n", "\n"):gsub("\n+$", "")
        local updated = replacements[normalized]
        if not updated or #updated > 255 then return end
        EditMacro(index, nil, nil, updated)
        local _, _, saved = GetMacroInfo(index)
        if saved ~= updated then return end
        -- Duplicate macro names require keeping wheel body identities in sync.
        for _, entry in pairs(ForeverTweaksQuickMenu or {}) do
            if type(entry) == "table" and entry.kind == "macro" and entry.name == name
                and entry.body == body and entry.character == (index > base) then
                entry.body = updated
            end
        end
    end
    for index = 1, accountCount do Update(index) end
    for index = base + 1, base + characterCount do Update(index) end
end

-- Defer edits until other macro observers have finished their current update.
local queued = false
local function QueueUpdate()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        UpdateMacros()
    end)
end
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("CURSOR_CHANGED")
driver:RegisterEvent("UPDATE_MACROS")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then RestoreErrorHandling() else QueueUpdate() end
end)
