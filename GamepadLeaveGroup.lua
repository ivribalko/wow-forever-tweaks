-- Provides immediate group leaving for the quick wheel.
local function LeaveParty()
    if IsInGroup() then C_PartyInfo.ConfirmLeaveParty() end
end

-- Secure Share release calls this addon-owned method after closing the wheel.
local leaveRequest = CreateFrame("Button", "ForeverTweaksLeaveGroupRequest", UIParent)
leaveRequest:EnableMouse(false)
leaveRequest.LeaveParty = LeaveParty
