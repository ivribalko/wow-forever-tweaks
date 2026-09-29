-- A compact minimap button that reloads the interface on a left click.
local button = CreateFrame("Button", "ForeverTweaksReloadButton", Minimap)
button:SetSize(24, 24)
button:SetPoint("RIGHT", ForeverTweaksCompactButton, "LEFT", -4, 0)
button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
button:RegisterForClicks("LeftButtonUp")
-- Use the day/night indicator's native rim around Blizzard's refresh symbol.
local border = button:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)

local function CreateReloadTexture(layer, brightness)
    local texture = button:CreateTexture(nil, layer)
    texture:SetSize(16, 16)
    texture:SetPoint("CENTER")
    texture:SetAtlas("UI-RefreshButton", false)
    texture:SetVertexColor(brightness, brightness, brightness)
    return texture
end

button:SetNormalTexture(CreateReloadTexture("ARTWORK", 1))
button:SetPushedTexture(CreateReloadTexture("ARTWORK", 0.65))
local highlight = button:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetAtlas("UI-HUD-Minimap-Frame-Cycle", false)
highlight:SetAlpha(0.35)
button:SetHighlightTexture(highlight, "ADD")
button:SetScript("OnClick", function()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end)

