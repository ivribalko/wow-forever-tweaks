-- Handle merchant chores for the current visit, using personal funds for repairs.
local events = CreateFrame("Frame")
local repairPending = false

local function RepairItems()
    if not repairPending or not CanMerchantRepair() then
        return
    end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost == 0 then
        repairPending = false
    elseif GetMoney() >= cost then
        -- Clear before requesting repairs because money events can fire immediately.
        repairPending = false
        RepairAllItems(false)
    end
end

local function SellJunk()
    if C_MerchantFrame.IsSellAllJunkEnabled() then
        C_MerchantFrame.SellAllJunkItems()
        return
    end

    -- Classic merchants can omit the bulk-sell feature; sell gray bag stacks directly.
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if item and item.quality == Enum.ItemQuality.Poor
                and not item.isLocked and not item.hasNoValue then
                C_Container.UseContainerItem(bag, slot)
            end
        end
    end
end

events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_CLOSED" then
        repairPending = false
        self:UnregisterEvent("PLAYER_MONEY")
    elseif event == "MERCHANT_SHOW" then
        repairPending = true
        self:RegisterEvent("PLAYER_MONEY")
        SellJunk()
        RepairItems()
    elseif event == "PLAYER_MONEY" then
        -- Junk-sale proceeds may make an initially unaffordable repair possible.
        RepairItems()
    end
end)
