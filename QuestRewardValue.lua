-- Mark the most valuable selectable quest rewards with independent coin visuals.
local observer = CreateFrame("Frame")
local markers = {}

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
        -- Fullscreen menu isolation fades UIParent children unrelated to its panel.
        -- Keep this visual outside that tree and copy the native visibility below.
        marker = CreateFrame("Frame")
        marker:EnableMouse(false)
        marker.texture = marker:CreateTexture(nil, "OVERLAY")
        marker.texture:SetAllPoints()
        marker.texture:SetAtlas("coin-gold")
        markers[index] = marker
    end
    -- The reward buttons belong to a scroll child; their frame levels are not
    -- a reliable stacking reference for an independent overlay outside it.
    marker:SetFrameStrata("TOOLTIP")
    marker:SetFrameLevel(button:GetFrameLevel() + 10)
    marker:SetScale(UIParent:GetEffectiveScale())
    marker:SetSize(14 * scale, 14 * scale)
    marker:ClearAllPoints()
    marker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (left + 3) * scale, (top - 3) * scale)
    marker:SetAlpha(button:GetEffectiveAlpha())
    marker:Show()
end

local function Refresh()
    HideMarkers()
    if not UIParent:IsVisible() or not QuestFrameRewardPanel or not QuestFrameRewardPanel:IsVisible()
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

-- Read native state every frame so ready rewards appear on the first visual
-- update, without a timer delay, hooks, or native controller registrations.
observer:SetScript("OnUpdate", Refresh)
