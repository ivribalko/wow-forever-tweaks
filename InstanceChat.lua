-- Ensure a permanent group-chat tab after native chat settings have loaded.
local function ConfigureInstanceChat()
    local instanceFrame
    for index = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. index]
        local name, _, _, _, _, _, shown = GetChatWindowInfo(index)
        if frame and not frame.isTemporary and (shown or frame.isDocked)
            and name == "Instance" then
            instanceFrame = frame
            break
        end
    end

    if not instanceFrame then
        instanceFrame = FCF_OpenNewWindow("Instance", true)
    end
    if not instanceFrame then
        return
    end

    for _, group in ipairs({
        "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
        "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
    }) do
        if not instanceFrame:ContainsMessageGroup(group) then
            instanceFrame:AddMessageGroup(group)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ConfigureInstanceChat()
end)
