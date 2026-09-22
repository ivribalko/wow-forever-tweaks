-- Preview the selected crafting result with native equipped-item comparisons.
local events = CreateFrame("Frame")
local installed = false

local function InstallProfessionTooltip()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if installed or not form then
        return
    end
    installed = true

    local tooltip = CreateFrame("GameTooltip", "ForeverTweaksRecipeTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip:EnableMouse(false)
    tooltip.shoppingTooltips = {}
    for index = 1, 2 do
        local comparison = CreateFrame("GameTooltip", "ForeverTweaksRecipeComparison" .. index,
            UIParent, "ShoppingTooltipTemplate")
        comparison:SetFrameStrata("TOOLTIP")
        comparison:SetClampedToScreen(true)
        comparison:EnableMouse(false)
        comparison:Hide()
        tooltip.shoppingTooltips[index] = comparison
    end
    tooltip:Hide()

    local function HidePreview()
        tooltip:Hide()
        -- Clear only this preview's comparison state, preserving other item tooltips.
        TooltipComparisonManager:Clear(tooltip)
        for _, comparison in ipairs(tooltip.shoppingTooltips) do
            comparison:Hide()
        end
    end

    local function UpdatePreview()
        local recipe = form:GetRecipeInfo()
        if not form:IsVisible() or not recipe or not form.recipeSchematic or not form.transaction
            or not form.OutputIcon:IsShown() or form.isRecraft or form.isInspection
            or GameTooltip:IsShown() then
            HidePreview()
            return
        end

        -- Match the output icon's native OnEnter data, including reagent allocations.
        local reagents = form.transaction:CreateCraftingReagentInfoTbl()
        tooltip:SetOwner(form.OutputIcon, "ANCHOR_NONE")
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 8, -40)
        tooltip:SetRecipeResultItem(form.recipeSchematic.recipeID, reagents,
            form.transaction:GetAllocationItemGUID(), form:GetCurrentRecipeLevel(),
            form:GetOutputOverrideQualityID())

        local data = tooltip:GetPrimaryTooltipData()
        if not data then
            HidePreview()
            return
        end
        tooltip:Show()
        TooltipComparisonManager:Clear(tooltip)
        GameTooltip_ShowCompareItem(tooltip)
    end

    -- A child driver stops with the crafting form; native hover tooltips take priority.
    -- Rebuilding also handles delayed item data, changed reagents, and equipped gear.
    local driver = CreateFrame("Frame", nil, form)
    local elapsedTime = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime >= 0.2 then
            elapsedTime = 0
            UpdatePreview()
        end
    end)
    driver:SetScript("OnHide", HidePreview)
    hooksecurefunc(form, "Init", function()
        HidePreview()
        elapsedTime = 0.2
    end)

    events:UnregisterAllEvents()
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", InstallProfessionTooltip)
InstallProfessionTooltip()
