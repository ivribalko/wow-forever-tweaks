-- Keep action-button countdowns in native single-value units instead of M:SS.
local function FormatCooldown(cooldown)
    if cooldown and cooldown.SetCountdownAbbrevThreshold then
        -- A threshold below one minute disables the native M:SS abbreviation.
        cooldown:SetCountdownAbbrevThreshold(0)
    end
end

local function FormatButton(button)
    FormatCooldown(button.cooldown)
    FormatCooldown(button.chargeCooldown)
    FormatCooldown(button.lossOfControlCooldown)
end

-- The shared path also covers controller buttons and dynamically created flyouts.
hooksecurefunc("ActionButton_ApplyCooldown", function(normal, _, charge, _, lossOfControl)
    FormatCooldown(normal)
    FormatCooldown(charge)
    FormatCooldown(lossOfControl)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    for _, button in pairs(ActionBarButtonEventsFrame.frames) do
        FormatButton(button)
    end
end)
