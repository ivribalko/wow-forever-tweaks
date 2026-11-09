-- Filter and sort native quest watches without replacing tracker Lua methods.
local events = CreateFrame("Frame")
local queued = false
local sorting = false
local lastRejectedOrder

-- Copy location data without changing the map used by Blizzard's quest POIs.
local function ReadLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    local inInstance = IsInInstance()
    local names, maps, quests = {}, {}, {}
    local function AddName(name)
        if name and name ~= "" then names[name] = true end
    end
    AddName(GetRealZoneText())
    AddName(GetZoneText())
    if inInstance then AddName(GetInstanceInfo()) end
    local info = mapID and C_Map.GetMapInfo(mapID)
    -- Outdoors, subzones share their zone's quests; never ascend to a continent.
    while not inInstance and info and info.mapType > Enum.UIMapType.Zone do
        local parent = C_Map.GetMapInfo(info.parentMapID)
        if not parent or parent.mapType < Enum.UIMapType.Zone then break end
        info = parent
        mapID = info.mapID
    end
    -- A mapless instance can report its outdoor entrance map; ignore that map.
    if info and info.mapType >= Enum.UIMapType.Zone
        and (not inInstance or info.mapType >= Enum.UIMapType.Dungeon) then
        AddName(info.name)
        maps[mapID] = true
        if inInstance then
            local group = C_Map.GetMapGroupID(mapID)
            for _, floor in ipairs(group and C_Map.GetMapGroupMembersInfo(group) or {}) do
                maps[floor.mapID] = true
            end
        end
    end
    if not next(names) and not next(maps) then return end
    for id in pairs(maps) do
        for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(id) or {}) do
            quests[poi.questID] = true
        end
    end
    return names, quests
end

local function FilterQuestWatches()
    local names, localQuests = ReadLocation()
    if not names then return end
    if type(ForeverTweaksHiddenQuestWatches) ~= "table" then
        ForeverTweaksHiddenQuestWatches = {}
    end
    local hidden = ForeverTweaksHiddenQuestWatches
    local candidates = {}
    for id in pairs(hidden) do candidates[id] = true end
    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if id then candidates[id] = true end
    end
    for id in pairs(candidates) do
        if not C_QuestLog.IsOnQuest(id) then
            hidden[id] = nil
        else
            local headerIndex = C_QuestLog.GetHeaderIndexForQuest(id)
            local header = headerIndex and C_QuestLog.GetInfo(headerIndex)
            -- Named dungeon headers cover instances without quest POI maps.
            local matches = localQuests[id] or (header and names[header.title])
            if matches then
                if hidden[id] then
                    C_QuestLog.AddQuestWatch(id)
                    if C_QuestLog.GetQuestWatchType(id) ~= nil then hidden[id] = nil end
                end
            else
                -- Persist intent before removing the native watch, including reloads.
                hidden[id] = true
                if C_QuestLog.GetQuestWatchType(id) ~= nil then
                    C_QuestLog.RemoveQuestWatch(id)
                end
            end
        end
    end
end

local function ReadWatches()
    local entries = {}
    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if not questID then
            return
        end
        local level = C_QuestLog.GetQuestDifficultyLevel(questID)
        if (issecretvalue and issecretvalue(level)) or type(level) ~= "number" or level <= 0 then
            level = math.huge
        end
        entries[index] = { id = questID, level = level, index = index }
    end
    return entries
end

local function SortQuestWatches()
    queued = false
    if not IsLoggedIn() or InCombatLockdown() or sorting then
        return
    end
    sorting = true
    FilterQuestWatches()
    sorting = false
    local entries = ReadWatches()
    if not entries or #entries < 2 then
        return
    end
    table.sort(entries, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.index < b.index
    end)
    local desiredIDs = {}
    local changed = false
    for index, entry in ipairs(entries) do
        desiredIDs[index] = tostring(entry.id)
        changed = changed or entry.index ~= index
    end
    if not changed then
        lastRejectedOrder = nil
        return
    end
    local desiredOrder = table.concat(desiredIDs, ",")
    if desiredOrder == lastRejectedOrder then
        return
    end

    -- Native add/remove APIs keep the next tracker rebuild in Blizzard's context.
    -- AddQuestWatch inserts at the front, so insert highest-to-lowest to leave
    -- the native list lowest-first. Reverse ties too to preserve their order.
    local selectedQuest = C_SuperTrack.GetSuperTrackedQuestID()
    sorting = true
    for index = #entries, 1, -1 do
        local entry = entries[index]
        C_QuestLog.RemoveQuestWatch(entry.id)
        C_QuestLog.AddQuestWatch(entry.id)
    end
    if selectedQuest and C_SuperTrack.GetSuperTrackedQuestID() ~= selectedQuest then
        C_SuperTrack.SetSuperTrackedQuestID(selectedQuest)
    end
    sorting = false

    -- Some client builds may impose their own insertion order. Do not keep cycling
    -- watches in response to the events generated by an unsuccessful reorder.
    local accepted = C_QuestLog.GetNumQuestWatches() == #entries
    for index, entry in ipairs(entries) do
        if C_QuestLog.GetQuestIDForQuestWatchIndex(index) ~= entry.id then
            accepted = false
            break
        end
    end
    if not accepted then
        lastRejectedOrder = desiredOrder
    else
        lastRejectedOrder = nil
    end
end

local function QueueSort()
    if sorting or queued then
        return
    end
    queued = true
    C_Timer.After(0, SortQuestWatches)
end

-- Zone changes also cause Blizzard to sort watches by its native criteria.
hooksecurefunc(C_QuestLog, "SortQuestWatches", QueueSort)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "QUEST_POI_UPDATE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", QueueSort)
