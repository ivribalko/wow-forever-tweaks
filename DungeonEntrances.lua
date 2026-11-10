-- Draw missing dungeon entrances using native artwork outside native pin/controller pools.
local pinTemplate = "DungeonEntrancePinTemplate"
local markers = {}
local filterCheckbox
local cachedMapID
local cachedNodes
local refreshPending = true
local nextDataRefresh = 0

-- Entrance/approach coordinates checked against the Forever dungeon-location reference
-- linked in AGENTS.md. Values are map ID, x%, y%, label, optional raid atlas/zone-only flag.
local fallbackEntrances = {
    {1440, 14.00, 13.10, "Blackfathom Deeps"},
    {1418, 44.53, 12.12, "Uldaman"},
    {1418, 65.05, 43.37, "Uldaman (Side Entrance)"},
    {1413, 49.13, 93.48, "Razorfen Downs"},
    {1413, 41.89, 89.50, "Razorfen Kraul"},
    {1413, 45.97, 36.34, "Wailing Caverns"},
    {1428, 29.94, 47.78, "Blackrock Mountain", false, false,
        "Blackrock Depths, Blackrock Spire, Molten Core, Blackwing Lair"},
    {1427, 34.70, 86.00, "Blackrock Mountain", false, true,
        "Blackrock Depths, Blackrock Spire, Molten Core, Blackwing Lair"},
    {1443, 29.10, 62.50, "Maraudon"},
    {1426, 24.46, 39.81, "Gnomeregan"},
    {1445, 52.90, 77.70, "Onyxia's Lair", true},
    {1423, 30.85, 17.00, "Stratholme"},
    {1423, 39.00, 26.00, "Naxxramas", true},
    {1444, 59.11, 43.28, "Dire Maul"},
    {1444, 77.06, 36.95, "Dire Maul (Eastern Entrance)"},
    {1454, 51.60, 49.83, "Ragefire Chasm"},
    {1451, 29.09, 93.20, "Ahn'Qiraj", true, false,
        "Ruins of Ahn'Qiraj, Temple of Ahn'Qiraj"},
    {1481, 36.20, 84.20, "Ruins of Ahn'Qiraj", true, true},
    {1481, 23.50, 86.20, "Temple of Ahn'Qiraj", true, true},
    {1421, 44.80, 67.80, "Shadowfang Keep"},
    {1453, 40.28, 55.21, "The Stockade"},
    {1435, 69.50, 52.50, "The Temple of Atal'hakkar"},
    {1446, 38.72, 20.00, "Zul'Farrak"},
    {1420, 85.30, 32.20, "Scarlet Monastery"},
    {1458, 72.50, 11.40, "Ruins of Lordaeron"},
    {1422, 69.00, 72.90, "Scholomance"},
    {1436, 42.57, 71.71, "Deadmines"},
    {1434, 53.96, 17.57, "Zul'Gurub", true},
}

-- Project only into ancestor maps, never into unrelated overlapping map rectangles.
local function ProjectEntrance(sourceMapID, mapID, x, y)
    if sourceMapID == mapID then return x, y end
    local current = C_Map.GetMapInfo(sourceMapID)
    local visited = {}
    while current and current.parentMapID and current.parentMapID ~= 0 do
        if visited[current.mapID] then return end
        visited[current.mapID] = true
        local parentID = current.parentMapID
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(current.mapID, parentID)
        if not minX or not maxX or not minY or not maxY then return end
        x = minX + x * (maxX - minX)
        y = minY + y * (maxY - minY)
        if parentID == mapID then return x, y end
        current = C_Map.GetMapInfo(parentID)
    end
end

local function GetFallbackEntrances(mapID)
    local nodes = {}
    for index, entrance in ipairs(fallbackEntrances) do
        if not entrance[6] or entrance[1] == mapID then
            local x, y = ProjectEntrance(entrance[1], mapID, entrance[2] / 100, entrance[3] / 100)
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                nodes[#nodes + 1] = {
                    areaPoiID = -index,
                    position = CreateVector2D(x, y),
                    name = entrance[4],
                    description = entrance[7],
                    atlasName = entrance[5] and "Raid" or "Dungeon",
                }
            end
        end
    end
    return nodes
end

local reportedCount = 0
local usingFallback = false

local function DungeonEntrancesEnabled()
    return ForeverTweaksDungeonEntrancesEnabled ~= false
end

local function ToggleDungeonEntrances()
    ForeverTweaksDungeonEntrancesEnabled = not DungeonEntrancesEnabled()
    refreshPending = true
end

-- Observe the dropdown without adding descriptions, callbacks, or native children.
local function RefreshDungeonEntranceCheckbox()
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
        label:SetText("Dungeon Entrances")
        checkbox:SetScript("OnClick", function(self)
            ToggleDungeonEntrances()
            self:SetChecked(DungeonEntrancesEnabled())
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
    filterCheckbox:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom + height + 4)
    filterCheckbox:SetChecked(DungeonEntrancesEnabled())
    filterCheckbox:Show()
end

local function HideTooltip(marker)
    if GameTooltip:IsOwned(marker) then
        GameTooltip:Hide()
    end
end

local function ShowTooltip(marker)
    local node = marker.node
    if not node then
        return
    end
    GameTooltip:SetOwner(marker, "ANCHOR_RIGHT")
    GameTooltip:SetText(node.name)
    if node.description and node.description ~= "" then
        GameTooltip:AddLine(node.description, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function GetMarker(index, canvas)
    local marker = markers[index]
    if not marker then
        -- Plain visual frames never join native navigation, tag, or pin pools.
        marker = CreateFrame("Frame", nil, canvas)
        marker:SetSize(20, 20)
        marker:SetFrameLevel(canvas:GetFrameLevel() + 20)
        marker:SetMouseClickEnabled(false)
        marker:SetMouseMotionEnabled(true)
        marker.icon = marker:CreateTexture(nil, "ARTWORK")
        marker.icon:SetAllPoints()
        marker:SetScript("OnEnter", ShowTooltip)
        marker:SetScript("OnLeave", HideTooltip)
        marker:SetScript("OnHide", HideTooltip)
        markers[index] = marker
    end
    return marker
end

--@alpha@
-- Keep only bounded numeric/visual evidence, never native frames or player data.
local function CaptureEntrances(mapID, apiAvailable, nodes, nativeCount, drawnCount)
    if type(ForeverTweaksDiagnostics) ~= "table" then
        ForeverTweaksDiagnostics = {}
    end
    local captures = ForeverTweaksDiagnostics.dungeonEntrances
    if type(captures) ~= "table" then
        captures = {}
        ForeverTweaksDiagnostics.dungeonEntrances = captures
    end
    local snapshot = {
        mapID = mapID, apiAvailable = apiAvailable,
        enabled = DungeonEntrancesEnabled(), reported = reportedCount,
        fallback = usingFallback, available = #(nodes or {}),
        native = nativeCount, drawn = drawnCount, nodes = {},
    }
    for index, node in ipairs(nodes or {}) do
        if index > 40 then break end
        local x, y
        if node.position then x, y = node.position:GetXY() end
        snapshot.nodes[index] = {
            areaPoiID = node.areaPoiID, atlas = node.atlasName, x = x, y = y,
            atlasAvailable = node.atlasName and C_Texture.GetAtlasInfo(node.atlasName) ~= nil,
        }
    end
    for index, previous in ipairs(captures) do
        if previous.mapID == mapID then
            captures[index] = snapshot
            return
        end
    end
    if #captures >= 12 then table.remove(captures, 1) end
    captures[#captures + 1] = snapshot
end
--@end-alpha@

local function RefreshDungeonEntrances()
    local map = WorldMapFrame
    if not map or not map:IsShown() then
        cachedMapID = nil
        return
    end
    local mapID = map:GetMapID()
    if not mapID then
        return
    end
    local apiAvailable = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap ~= nil
    if mapID ~= cachedMapID or refreshPending or GetTime() >= nextDataRefresh then
        cachedNodes = apiAvailable and C_EncounterJournal.GetDungeonEntrancesForMap(mapID) or {}
        reportedCount = #cachedNodes
        usingFallback = reportedCount == 0
        if usingFallback then cachedNodes = GetFallbackEntrances(mapID) end
        nextDataRefresh = GetTime() + 1
        cachedMapID = mapID
        refreshPending = false
    end

    local enabled = DungeonEntrancesEnabled()
    local nativeCount = 0
    for pin in map:EnumeratePinsByTemplate(pinTemplate) do
        nativeCount = nativeCount + 1
        -- Alpha-only suppression; native pin visibility cannot suppress our markers.
        if pin.Texture then pin.Texture:SetAlpha(0) end
    end

    local canvas = map:GetCanvas()
    local width, height = canvas:GetSize()
    local scale = map:GetEffectiveScale() / canvas:GetEffectiveScale()
    local count = 0
    if enabled then
        for _, node in ipairs(cachedNodes or {}) do
            if node.position
                and node.atlasName and node.atlasName ~= "" then
                local x, y = node.position:GetXY()
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    count = count + 1
                    local marker = GetMarker(count, canvas)
                    if marker.node and marker.node.areaPoiID ~= node.areaPoiID then
                        HideTooltip(marker)
                    end
                    marker.node = node
                    marker:SetScale(scale)
                    marker:ClearAllPoints()
                    marker:SetPoint("CENTER", canvas, "TOPLEFT", x * width / scale, -y * height / scale)
                    marker.icon:SetAtlas(node.atlasName)
                    marker:Show()
                end
            end
        end
    end
    --@alpha@
    CaptureEntrances(mapID, apiAvailable == true, cachedNodes, nativeCount, count)
    --@end-alpha@
    for index = count + 1, #markers do
        markers[index]:Hide()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("AREA_POIS_UPDATED")
events:SetScript("OnEvent", function()
    refreshPending = true
end)
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        elapsed = 0
        RefreshDungeonEntranceCheckbox()
        RefreshDungeonEntrances()
    end
end)
