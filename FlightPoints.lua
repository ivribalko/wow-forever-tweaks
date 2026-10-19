-- Draw missing flight points without entering the native map pin/controller pools.
local pinTemplate = "FlightPointPinTemplate"
local markers = {}
local filterCheckbox
local cachedMapID
local cachedNodes
local refreshPending = true

local function FlightPointsEnabled()
    return ForeverTweaksFlightPointsEnabled ~= false
end

local function ToggleFlightPoints()
    ForeverTweaksFlightPointsEnabled = not FlightPointsEnabled()
    refreshPending = true
end

-- Observe the dropdown without adding descriptions, callbacks, or native children.
local function RefreshFlightPointCheckbox()
    local map = WorldMapFrame
    local dropdown = map and map.WorldMapTrackingOptionsButton
    local menu = dropdown and dropdown.menu
    if not map or not map:IsShown() or not menu or not menu:IsShown() then
        if filterCheckbox then
            filterCheckbox:Hide()
        end
        return
    end

    local left, bottom, width = menu:GetRect()
    if not left or not bottom or not width then
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
        label:SetText("Flight Points")
        checkbox:SetScript("OnClick", function(self)
            ToggleFlightPoints()
            self:SetChecked(FlightPointsEnabled())
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
    filterCheckbox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom - 4)
    filterCheckbox:SetChecked(FlightPointsEnabled())
    filterCheckbox:Show()
end

local function IsFriendlyNode(node)
    local faction = UnitFactionGroup("player")
    return node.faction == Enum.FlightPathFaction.Neutral
        or (node.faction == Enum.FlightPathFaction.Horde and faction == "Horde")
        or (node.faction == Enum.FlightPathFaction.Alliance and faction == "Alliance")
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
    if node.isUndiscovered then
        local description = UNDISCOVERED_NEUTRAL_FLIGHTPOINT
        if node.faction == Enum.FlightPathFaction.Horde then
            description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_HORDE)
        elseif node.faction == Enum.FlightPathFaction.Alliance then
            description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_ALLIANCE)
        end
        GameTooltip:AddLine(description, 1, 0.82, 0, true)
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

local function RefreshFlightPoints()
    local map = WorldMapFrame
    if not map or not map:IsShown() or not C_TaxiMap then
        cachedMapID = nil
        return
    end
    local mapID = map:GetMapID()
    if not mapID then
        return
    end
    if mapID ~= cachedMapID or refreshPending then
        cachedNodes = C_TaxiMap.GetTaxiNodesForMap(mapID) or {}
        cachedMapID = mapID
        refreshPending = false
    end

    local enabled = FlightPointsEnabled()
    local existing = {}
    for pin in map:EnumeratePinsByTemplate(pinTemplate) do
        if pin.poiInfo then
            existing[pin.poiInfo.nodeID] = true
            -- Visual-only writes: never release native pins or invoke providers.
            if pin.Texture then
                pin.Texture:SetAlpha(enabled and (pin.poiInfo.isUndiscovered and 0.55 or 1) or 0)
            end
        end
    end

    local canvas = map:GetCanvas()
    local width, height = canvas:GetSize()
    local scale = map:GetEffectiveScale() / canvas:GetEffectiveScale()
    local count = 0
    if enabled then
        for _, node in ipairs(cachedNodes or {}) do
            if not existing[node.nodeID] and IsFriendlyNode(node) then
                local x, y = node.position:GetXY()
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    count = count + 1
                    local marker = GetMarker(count, canvas)
                    if marker.node and marker.node.nodeID ~= node.nodeID then
                        HideTooltip(marker)
                    end
                    marker.node = node
                    marker:SetScale(scale)
                    marker:ClearAllPoints()
                    marker:SetPoint("CENTER", canvas, "TOPLEFT", x * width / scale, -y * height / scale)
                    marker.icon:SetAtlas(node.atlasName)
                    marker.icon:SetAlpha(node.isUndiscovered and 0.55 or 1)
                    marker:Show()
                end
            end
        end
    end
    for index = count + 1, #markers do
        markers[index]:Hide()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
events:SetScript("OnEvent", function()
    refreshPending = true
end)
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.1 then
        elapsed = 0
        RefreshFlightPointCheckbox()
        RefreshFlightPoints()
    end
end)
