-- Mark the most valuable selectable quest rewards with independent coin visuals.
local observer = CreateFrame("Frame")
local markers = {}
local elapsed = 0

local function HideMarkers()
    for _, marker in ipairs(markers) do
        marker:Hide()
    end
end

local function ShowMarker(button, index)
    local icon = button.Icon
    local scroll = QuestRewardScrollFrame
    if not icon or not icon:IsVisible() or not scroll then return end

    local scale = icon:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, top = icon:GetLeft(), icon:GetTop()
    local bottom = icon:GetBottom()
    local scrollScale = scroll:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local scrollTop, scrollBottom = scroll:GetTop(), scroll:GetBottom()
    if not left or not top or not bottom or not scrollTop or not scrollBottom then return end
    -- Independent frames do not inherit the native scroll viewport's clipping.
    if top * scale > scrollTop * scrollScale or bottom * scale < scrollBottom * scrollScale then return end

    local marker = markers[index]
    if not marker then
        marker = CreateFrame("Frame", nil, UIParent)
        marker:EnableMouse(false)
        marker.texture = marker:CreateTexture(nil, "OVERLAY")
        marker.texture:SetAllPoints()
        marker.texture:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        markers[index] = marker
    end
    marker:SetFrameStrata(button:GetFrameStrata())
    marker:SetFrameLevel(button:GetFrameLevel() + 10)
    marker:SetSize(14 * scale, 14 * scale)
    marker:ClearAllPoints()
    marker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * scale, top * scale)
    marker:SetAlpha(button:GetEffectiveAlpha())
    marker:Show()
end

local function Refresh()
    HideMarkers()
    if not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsVisible()
        or not QuestInfoFrame or QuestInfoFrame.questLog then return end

    local count = GetNumQuestChoices()
    if not count or count < 2 then return end
    local values, highest = {}, 0
    for index = 1, count do
        local link = GetQuestItemLink("choice", index)
        local _, _, quantity = GetQuestItemInfo("choice", index)
        if not link or not quantity then return end
        local price = select(11, C_Item.GetItemInfo(link))
        -- Retry while item data loads; a partial list could mark the wrong reward.
        if not price then return end
        values[index] = price * quantity
        highest = math.max(highest, values[index])
    end
    if highest <= 0 then return end

    local rewards = QuestInfoFrame.rewardsFrame
    if not rewards or not rewards.RewardButtons then return end
    local markerIndex = 0
    for _, button in ipairs(rewards.RewardButtons) do
        if button:IsVisible() and button.type == "choice" and values[button:GetID()] == highest then
            markerIndex = markerIndex + 1
            ShowMarker(button, markerIndex)
        end
    end
end

-- Read native state without hooks, native children, or controller registrations.
observer:SetScript("OnUpdate", function(_, delta)
    if not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsVisible() then
        HideMarkers()
        elapsed = 0
        return
    end
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    Refresh()
end)
