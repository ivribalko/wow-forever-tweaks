-- Mark the closest unfinished quest POI, using a rim arrow while out of range.
local arrow = CreateFrame("Frame", "ForeverTweaksQuestArrow", Minimap)
arrow:SetSize(22, 22)
arrow:SetFrameLevel(Minimap:GetFrameLevel() + 11)
arrow:EnableMouse(false)
arrow:Hide()

local texture = arrow:CreateTexture(nil, "OVERLAY")
texture:SetAtlas("Navigation-Tracked-Arrow")
texture:SetAllPoints()

local marker = arrow:CreateTexture(nil, "OVERLAY")
marker:SetAtlas("Navigation-Tracked-Icon")
marker:SetSize(14, 14)
marker:SetPoint("CENTER")
marker:Hide()

local candidates = {}
local currentMapID
local mapWidth, mapHeight
local scanElapsed, drawElapsed = 1, 0

local function IsPublicNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function IsIncompleteQuest(questID)
    if not C_QuestLog.IsOnQuest(questID) or C_QuestLog.IsComplete(questID)
        or C_QuestLog.IsFailed(questID) then
        return false
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
            and IsIncompleteQuest(poi.questID) then
            candidates[#candidates + 1] = { x = poi.x, y = poi.y }
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
    local inRange = pixelDistance ~= nil and pixelDistance <= mapRadius - 8
    local radius = inRange and pixelDistance or math.max(0, mapRadius - 12)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
    marker:SetShown(inRange)
    texture:SetShown(not inRange)
    if not inRange then
        -- Match the native SuperTrackedFrame arrow's up-facing atlas and rotation.
        texture:SetRotation(-Vector2D_CalculateAngleBetween(x, y, 0, 1))
    end
    arrow:Show()
end

-- Keep the driver separate: a hidden arrow must still discover new objectives.
local driver = CreateFrame("Frame", nil, Minimap)
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
    local closestDistance, closestEast, closestNorth
    for _, candidate in ipairs(candidates) do
        local east = (candidate.x - playerX) * mapWidth
        local north = (playerY - candidate.y) * mapHeight
        local distance = east * east + north * north
        if not closestDistance or distance < closestDistance then
            closestDistance, closestEast, closestNorth = distance, east, north
        end
    end
    -- Keep the marker at the player's position on arrival until progress changes.
    if not closestDistance then
        arrow:Hide()
        return
    end
    DrawArrow(closestEast, closestNorth)
end)
