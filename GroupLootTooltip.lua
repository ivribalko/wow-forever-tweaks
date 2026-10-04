-- Show equipped-item comparisons for controller and mouse group loot rolls.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if tooltip ~= GameTooltip or not tooltip.supportsItemComparison then
        return
    end

    -- Both native roll interfaces use this getter; repeated data processing also
    -- covers delayed item data and refreshes without changing native focus handlers.
    local info = tooltip:GetProcessingTooltipInfo()
    if info and not info.append and info.getterName == "GetLootRollItem" then
        GameTooltip_ShowCompareItem(tooltip)
    end
end)
