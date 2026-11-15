-- Show client-reported unfinished quests in an independent region hover label.
local filterCheckbox, countLabel
local counts = {}

-- Classic outdoor-zone recommendations, used only when client levels are absent.
-- Sources are linked in AGENTS.md; keys are UI map IDs, not area IDs.
local zoneLevels = {
    [1411] = {1, 10}, [1412] = {1, 10}, [1413] = {10, 25},
    [1416] = {30, 40}, [1417] = {30, 40}, [1418] = {35, 45},
    [1419] = {47, 55}, [1420] = {1, 10}, [1421] = {10, 20},
    [1422] = {50, 60}, [1423] = {55, 60}, [1424] = {20, 30},
    [1425] = {40, 50}, [1426] = {1, 10}, [1427] = {43, 50},
    [1428] = {50, 60}, [1429] = {1, 10}, [1430] = {50, 60},
    [1431] = {20, 30}, [1432] = {10, 20}, [1433] = {15, 25},
    [1434] = {30, 45}, [1435] = {35, 45}, [1436] = {10, 20},
    [1437] = {20, 30}, [1438] = {1, 10}, [1439] = {10, 20},
    [1440] = {15, 30}, [1441] = {25, 35}, [1442] = {15, 27},
    [1443] = {30, 40}, [1444] = {40, 50}, [1445] = {35, 45},
    [1446] = {40, 50}, [1447] = {48, 55}, [1448] = {48, 55},
    [1449] = {48, 55}, [1451] = {55, 60}, [1452] = {55, 60},
}
local function QuestCountsEnabled()
    return ForeverTweaksQuestCountsEnabled == true
end
local function ToggleQuestCounts()
    ForeverTweaksQuestCountsEnabled = not QuestCountsEnabled()
    counts = {}
end

-- Observe the dropdown without adding descriptions, callbacks, or native children.
local function RefreshCheckbox()
    local map = WorldMapFrame
    local dropdown = map and map.WorldMapTrackingOptionsButton
    local menu = dropdown and dropdown.menu
    if not map or not map:IsShown() or not menu or not menu:IsShown() then
        if filterCheckbox then
            filterCheckbox:Hide()
        end
        return
    end

    local left, bottom, width, height = menu:GetRect()
    if not left or not bottom or not width or not height then
        return
    end
    if not filterCheckbox then
        local checkbox = CreateFrame("CheckButton", nil, UIParent, "BackdropTemplate")
        -- The native menu dismisses on an outside mouse-down. Handle the press
        -- before polling hides this independent row; mouse-up can arrive later.
        checkbox:RegisterForClicks("LeftButtonDown")
        checkbox:SetHeight(32)
        checkbox:SetClampedToScreen(true)
        checkbox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        checkbox:SetBackdropColor(0, 0, 0, 0.95)
        checkbox:SetBackdropBorderColor(1, 0.82, 0)
        local box = checkbox:CreateTexture(nil, "ARTWORK")
        box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        box:SetSize(26, 26)
        box:SetPoint("LEFT", 6, 0)
        local check = checkbox:CreateTexture(nil, "OVERLAY")
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetAllPoints(box)
        checkbox:SetCheckedTexture(check)
        local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", box, "RIGHT", 2, 0)
        label:SetText("Available Quests")
        checkbox:SetScript("OnClick", function(self)
            ToggleQuestCounts()
            self:SetChecked(QuestCountsEnabled())
        end)
        filterCheckbox = checkbox
    end

    -- Copy geometry numerically; the control remains outside the native menu tree.
    local scale = menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
    filterCheckbox:SetScale(scale)
    filterCheckbox:SetWidth(width)
    filterCheckbox:SetFrameStrata(menu:GetFrameStrata())
    filterCheckbox:SetFrameLevel(menu:GetFrameLevel() + 30)
    filterCheckbox:ClearAllPoints()
    filterCheckbox:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom + height + 68)
    filterCheckbox:SetChecked(QuestCountsEnabled())
    filterCheckbox:Show()
end

local function GetQuestCount(mapID)
    local cached = counts[mapID]
    if cached and GetTime() < cached.expires then return cached.count end
    if not C_QuestLine or not C_QuestLine.GetAvailableQuestLines then return end
    local offers = C_QuestLine.GetAvailableQuestLines(mapID)
    if not offers then return end
    local seen, count = {}, 0
    local function Add(questID)
        if questID and questID > 0 and not seen[questID]
            and not C_QuestLog.IsQuestFlaggedCompleted(questID)
            and not C_QuestLog.IsComplete(questID) then
            seen[questID] = true
            count = count + 1
        end
    end
    for _, offer in ipairs(offers) do
        if not offer.isHidden then Add(offer.questID) end
    end
    for _, quest in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
        if not quest.isMapIndicatorQuest then Add(quest.questID) end
    end
    counts[mapID] = { count = count, expires = GetTime() + 1 }
    return count
end

-- A separate mouse-hover label uses only frame geometry and client map APIs.
-- Do not inspect providers, hook native scripts, or invoke native map Lua methods.
local function RefreshCount()
    if countLabel then countLabel:Hide() end
    local map = WorldMapFrame
    local scroll = map and map.ScrollContainer
    local canvas = scroll and scroll.Child
    if not QuestCountsEnabled() or not map or not map:IsShown()
        or not scroll or not canvas then return end
    local mapID = map.mapID
    if not mapID then return end
    local current = C_Map.GetMapInfo(mapID)
    local region
    -- Area maps retain their own summary, including while hovering map pins.
    if current and current.mapType and current.mapType >= Enum.UIMapType.Zone then
        region = current
    elseif scroll:IsMouseMotionFocus() then
        local left, top = canvas:GetLeft(), canvas:GetTop()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        if not left or not top or width <= 0 or height <= 0 then return end
        local cursorX, cursorY = GetCursorPosition()
        local scale = canvas:GetEffectiveScale()
        if scale <= 0 then return end
        local x = (cursorX / scale - left) / width
        local y = (top - cursorY / scale) / height
        if x < 0 or x > 1 or y < 0 or y > 1 then return end
        region = C_Map.GetMapInfoAtPosition(mapID, x, y)
        if region and region.mapID == mapID then return end
    end
    if not region or not region.name then return end
    local count = GetQuestCount(region.mapID)
    if count == nil then return end
    local minLevel, maxLevel = C_Map.GetMapLevels(region.mapID)
    if not minLevel or not maxLevel or minLevel <= 0 or maxLevel <= 0 then
        local fallback = zoneLevels[region.mapID]
        if fallback then minLevel, maxLevel = fallback[1], fallback[2] end
    end
    local name = region.name
    if minLevel and maxLevel and minLevel > 0 and maxLevel > 0 then
        local levels = minLevel == maxLevel and tostring(minLevel)
            or (minLevel .. "–" .. maxLevel)
        name = name .. " (" .. levels .. ")"
    end
    if not countLabel then
        countLabel = CreateFrame("Frame", nil, UIParent)
        countLabel:EnableMouse(false)
        countLabel:SetFrameStrata("TOOLTIP")
        countLabel.text = countLabel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countLabel.text:SetPoint("TOPLEFT")
        countLabel.text:SetJustifyH("LEFT")
    end
    local uiScale = UIParent:GetEffectiveScale()
    local mapScale = map:GetEffectiveScale()
    local labelLeft = (scroll:GetLeft() or 0) * scroll:GetEffectiveScale() + 68 * mapScale
    local labelTop = scroll:GetTop()
    if not labelTop then return end
    -- Copy coordinate text geometry only; keep the overlay outside native layout.
    local fontSource = GameFontHighlightSmall
    local textScale = mapScale
    for _, panel in ipairs(map.overlayFrames or {}) do
        if panel.CursorCoords and panel.PlayerCoords then
            local label = panel.CursorCoords.Label
            if not label or not label:IsVisible() then label = panel.PlayerCoords.Label end
            if label and label:GetLeft() then
                labelLeft = label:GetLeft() * label:GetEffectiveScale()
                textScale = label:GetEffectiveScale()
                fontSource = label
            end
            break
        end
    end
    countLabel:SetScale(textScale / uiScale)
    countLabel.text:SetFont(fontSource:GetFont())
    countLabel.text:SetTextColor(fontSource:GetTextColor())
    countLabel.text:SetShadowColor(fontSource:GetShadowColor())
    countLabel.text:SetShadowOffset(fontSource:GetShadowOffset())
    countLabel.text:SetText(("%s\n%d quests"):format(name, count))
    countLabel:SetSize(countLabel.text:GetStringWidth(), countLabel.text:GetStringHeight())
    countLabel:ClearAllPoints()
    countLabel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        labelLeft / textScale, (labelTop * scroll:GetEffectiveScale() - 8 * mapScale) / textScale)
    countLabel:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function() counts = {} end)
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    RefreshCount()
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        elapsed = 0
        RefreshCheckbox()
    end
end)
