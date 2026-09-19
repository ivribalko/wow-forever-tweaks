-- Mark the closest quest objective or turn-in POI, using a rim arrow while out of range.
local arrow = CreateFrame("Frame", "ForeverTweaksQuestArrow", UIParent)
arrow:SetSize(33, 33)
-- Diel.lua creates the moon/sun outside the Minimap widget. Keep our artwork
-- outside that widget too, with independent layering over the minimap cluster.
arrow:SetFrameStrata("HIGH")
arrow:SetFixedFrameStrata(true)
arrow:SetFrameLevel(10)
arrow:SetFixedFrameLevel(true)
arrow:EnableMouse(false)
arrow:Hide()

local texture = arrow:CreateTexture(nil, "OVERLAY")
-- Use the native minimap super-tracker artwork.
texture:SetTexture("Interface\\Minimap\\SuperTrackerArrow")
texture:SetAllPoints()

local marker = arrow:CreateTexture(nil, "OVERLAY")
marker:SetTexture("Interface\\Minimap\\Minimap-Waypoint-MapPin-Tracked")
marker:SetSize(21, 21)
marker:SetPoint("CENTER")
marker:Hide()

-- Anchor the caption to the location header while sharing the arrow's visibility.
local questName = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questName:SetPoint("TOPLEFT", MinimapZoneText, "BOTTOMLEFT", 0, -3)
questName:SetSize(175, 14)
questName:SetJustifyH("LEFT")
questName:SetWordWrap(false)
questName:SetShadowOffset(1, -1)

local candidates = {}
local currentMapID
local mapWidth, mapHeight
local scanElapsed, drawElapsed = 1, 0

local function IsPublicNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function IsNavigableQuest(questID)
    if not C_QuestLog.IsOnQuest(questID) or C_QuestLog.IsFailed(questID) then
        return false
    end
    -- Completed quests use their native turn-in POI in GetQuestsOnMap.
    if C_QuestLog.IsComplete(questID) then
        return true
    end
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if not objectives or #objectives == 0 then
        return true
    end
    for _, objective in ipairs(objectives) do
        if not objective.finished then
            return true
        end
    end
    return false
end

local function ScanQuests(mapID)
    wipe(candidates)
    currentMapID = mapID
    mapWidth, mapHeight = C_Map.GetMapWorldSize(mapID)
    -- These coordinates are projected onto the requested map, as in Blizzard's
    -- QuestDataProvider. Do not reinterpret them using each POI's source mapID.
    for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
        if not poi.isQuestStart and IsPublicNumber(poi.questID)
            and IsPublicNumber(poi.x) and IsPublicNumber(poi.y)
            and poi.x >= 0 and poi.x <= 1 and poi.y >= 0 and poi.y <= 1
            and IsNavigableQuest(poi.questID) then
            candidates[#candidates + 1] = {
                x = poi.x, y = poi.y,
                title = C_QuestLog.GetTitleForQuestID(poi.questID),
            }
        end
    end
end

local function DrawArrow(east, north)
    local distance = math.sqrt(east * east + north * north)
    local angle = distance > 0 and math.atan2(north, east) or 0
    if GetCVarBool("rotateMinimap") and not C_Minimap.IsRotateMinimapIgnored() then
        local facing = GetPlayerFacing()
        if not IsPublicNumber(facing) then
            arrow:Hide()
            return
        end
        angle = angle - facing
    end
    local x, y = math.cos(angle), math.sin(angle)
    local mapRadius = math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2
    local viewRadius = C_Minimap.GetViewRadius()
    local pixelDistance
    if IsPublicNumber(viewRadius) and viewRadius > 0 then
        pixelDistance = distance * mapRadius / viewRadius
    end
    -- Leave room for the full marker inside the mask. Read the native range on
    -- every draw so zoom and indoor/outdoor changes immediately reposition it.
    local inRange = pixelDistance ~= nil and pixelDistance <= mapRadius - 11
    local radius = inRange and pixelDistance or math.max(0, mapRadius - 12)
    -- UIParent owns the overlay, so explicitly match the minimap's local units.
    arrow:SetScale(Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale())
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
    marker:SetShown(inRange)
    texture:SetShown(not inRange)
    if not inRange then
        -- The super-tracker arrow artwork faces up before rotation.
        texture:SetRotation(-Vector2D_CalculateAngleBetween(x, y, 0, 1))
    end
    arrow:Show()
end

-- Keep the driver separate: a hidden arrow must still discover new objectives.
local driver = CreateFrame("Frame", nil, Minimap)
driver:SetScript("OnHide", function()
    arrow:Hide()
end)
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("QUEST_LOG_UPDATE")
driver:RegisterEvent("QUEST_POI_UPDATE")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:SetScript("OnEvent", function()
    scanElapsed = 1
    arrow:Hide()
end)
driver:SetScript("OnUpdate", function(_, elapsed)
    scanElapsed = scanElapsed + elapsed
    drawElapsed = drawElapsed + elapsed
    if drawElapsed < 0.05 then
        return
    end
    drawElapsed = 0
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        arrow:Hide()
        return
    end
    if currentMapID ~= mapID or scanElapsed >= 1 then
        scanElapsed = 0
        ScanQuests(mapID)
    end
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position or not IsPublicNumber(mapWidth) or not IsPublicNumber(mapHeight)
        or mapWidth <= 0 or mapHeight <= 0 then
        arrow:Hide()
        return
    end
    local playerX, playerY = position:GetXY()
    if not IsPublicNumber(playerX) or not IsPublicNumber(playerY) then
        arrow:Hide()
        return
    end
    local closestDistance, closestEast, closestNorth, closestTitle
    for _, candidate in ipairs(candidates) do
        local east = (candidate.x - playerX) * mapWidth
        local north = (playerY - candidate.y) * mapHeight
        local distance = east * east + north * north
        if not closestDistance or distance < closestDistance then
            closestDistance, closestEast, closestNorth = distance, east, north
            closestTitle = candidate.title
        end
    end
    -- Keep the marker at the player's position on arrival until progress changes.
    if not closestDistance then
        arrow:Hide()
        return
    end
    questName:SetText(closestTitle or "")
    DrawArrow(closestEast, closestNorth)
end)
