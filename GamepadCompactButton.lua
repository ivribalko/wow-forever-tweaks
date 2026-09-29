-- Minimap shortcut for the native compact gamepad action-bar setting.
local cvar = "GamepadUseCompactActionBar"
local button = CreateFrame("Button", "ForeverTweaksCompactButton", Minimap)
button:SetSize(24, 24)
-- Center the two-button row below the minimap, with a four-pixel gap.
button:SetPoint("TOP", Minimap, "BOTTOM", 14, -6)
button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
button:RegisterForClicks("LeftButtonUp")

local border = button:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)

-- Three small action slots form an icon without requiring another image asset.
local slots = {}
for index = 1, 3 do
    local slot = button:CreateTexture(nil, "ARTWORK")
    slot:SetSize(4, 7)
    slot:SetPoint("CENTER", (index - 2) * 5, 0)
    slots[index] = slot
end

local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)
highlight:SetAlpha(0.35)
button:SetHighlightTexture(highlight, "ADD")

local function ShowTooltip()
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(GAMEPAD_TOGGLE_COMPACT_ACTION_BAR or "Use Compact Action Bar")
    GameTooltip:AddLine(C_CVar.GetCVarBool(cvar) and "Enabled" or "Disabled", 1, 1, 1)
    if InCombatLockdown() then
        GameTooltip:AddLine("Available after combat.", 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Left-click to toggle.", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function Update()
    local enabled = C_CVar.GetCVarBool(cvar)
    local alpha = InCombatLockdown() and 0.4 or 1
    for _, slot in ipairs(slots) do
        if enabled then
            slot:SetColorTexture(1, 0.82, 0, alpha)
        else
            slot:SetColorTexture(0.7, 0.7, 0.7, alpha)
        end
    end
    if GameTooltip:IsOwned(button) then ShowTooltip() end
end

button:SetScript("OnEnter", ShowTooltip)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)
button:SetScript("OnHide", function()
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end)
button:SetScript("OnClick", function()
    -- Native layout callbacks move protected action-bar anchors.
    if InCombatLockdown() then return end
    C_CVar.SetCVar(cvar, C_CVar.GetCVarBool(cvar) and "0" or "1")
    Update()
end)
button:RegisterEvent("PLAYER_LOGIN")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("CVAR_UPDATE")
button:SetScript("OnEvent", function(_, event, name)
    if event ~= "CVAR_UPDATE" or (name and name:lower() == cvar:lower()) then
        Update()
    end
end)
