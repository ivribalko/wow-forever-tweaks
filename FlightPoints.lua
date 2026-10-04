-- Supplement world-map flight points without changing taxi discovery or travel.
local pinTemplate = "FlightPointPinTemplate"
local hookedProviders = setmetatable({}, { __mode = "k" })
local menuInstalled = false

local function FlightPointsEnabled()
    return ForeverTweaksFlightPointsEnabled ~= false
end

local function ToggleFlightPoints()
    ForeverTweaksFlightPointsEnabled = not FlightPointsEnabled()
    for provider in pairs(hookedProviders) do
        provider:RefreshAllData()
    end
end

local function InstallFlightPointMenu()
    if menuInstalled or not Menu or type(Menu.ModifyMenu) ~= "function" then
        return
    end
    menuInstalled = true
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
        rootDescription:CreateCheckbox("Flight Points", FlightPointsEnabled, ToggleFlightPoints)
    end)
end

local function UpdateIcon(pin)
    if pin.Texture then
        -- Reset pooled icons too, including nodes learned since the last refresh.
        pin.Texture:SetAlpha(pin.poiInfo and pin.poiInfo.isUndiscovered and 0.55 or 1)
    end
end

local function AddMissingFlightPoints(provider)
    local map = provider:GetMap()
    if map ~= WorldMapFrame then
        return
    end
    if not FlightPointsEnabled() then
        map:RemoveAllPinsByTemplate(pinTemplate)
        return
    end
    local mapID = map:GetMapID()
    if not mapID then
        return
    end

    local existing = {}
    for pin in map:EnumeratePinsByTemplate(pinTemplate) do
        if pin.poiInfo then
            existing[pin.poiInfo.nodeID] = true
        end
        UpdateIcon(pin)
    end

    -- Query directly even when ShouldMapShowTaxiNodes hides the native layer.
    -- This API includes discovery state; it does not learn or unlock any node.
    local nodes = C_TaxiMap.GetTaxiNodesForMap(mapID) or {}
    local faction = UnitFactionGroup("player")
    for _, node in ipairs(nodes) do
        if not existing[node.nodeID] and provider:ShouldShowTaxiNode(faction, node) then
            -- Keep API-owned data unchanged when adding tooltip text.
            local info = CopyTable(node)
            if info.isUndiscovered then
                if info.faction == Enum.FlightPathFaction.Horde then
                    info.description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_HORDE)
                elseif info.faction == Enum.FlightPathFaction.Alliance then
                    info.description = UNDISCOVERED_FACTION_FLIGHTPOINT:format(FACTION_ALLIANCE)
                else
                    info.description = UNDISCOVERED_NEUTRAL_FLIGHTPOINT
                end
            end
            UpdateIcon(map:AcquirePin(pinTemplate, info))
            existing[node.nodeID] = true
        end
    end
end

local function InstallFlightPoints()
    InstallFlightPointMenu()
    if not WorldMapFrame or not WorldMapFrame.dataProviders
        or not FlightPointDataProviderMixin or not C_TaxiMap
        or type(C_TaxiMap.GetTaxiNodesForMap) ~= "function" then
        return
    end

    -- Hook only the world map's existing provider after its native cleanup.
    -- Its map-change and taxi-status events continue to own marker refreshes.
    for provider in pairs(WorldMapFrame.dataProviders) do
        if not hookedProviders[provider]
            and provider.ShouldShowTaxiNode == FlightPointDataProviderMixin.ShouldShowTaxiNode then
            hookedProviders[provider] = true
            hooksecurefunc(provider, "RefreshAllData", AddMissingFlightPoints)
            if WorldMapFrame:IsShown() then
                provider:RefreshAllData()
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" or addonName == "Blizzard_WorldMap"
        or addonName == "Blizzard_Menu" then
        InstallFlightPoints()
    end
end)
InstallFlightPoints()
