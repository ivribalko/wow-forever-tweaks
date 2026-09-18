-- A compact minimap button that reloads the interface on a left click.
local button = CreateFrame("Button", "ForeverTweaksReloadButton", Minimap)
button:SetSize(24, 24)
button:SetPoint("CENTER", Minimap, "TOPRIGHT", -6, -6)
button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
button:RegisterForClicks("LeftButtonUp")
button:SetNormalTexture("Interface\\AddOns\\ForeverTweaks\\Reload.tga")
button:SetPushedTexture("Interface\\AddOns\\ForeverTweaks\\Reload.tga")
button:GetPushedTexture():SetVertexColor(0.65, 0.65, 0.65)
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
button:SetScript("OnClick", function()
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end)
