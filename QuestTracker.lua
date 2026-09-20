-- Sort the native tracked-quest list without changing watch membership or filters.
local events = CreateFrame("Frame")
local function InstallQuestSorting()
    local tracker = QuestObjectiveTracker
    if not tracker or not tracker.BuildQuestWatchInfos then
        return
    end

    local buildQuestWatchInfos = tracker.BuildQuestWatchInfos
    tracker.BuildQuestWatchInfos = function(self)
        local infos = buildQuestWatchInfos(self)
        local levels, positions = {}, {}
        for index, info in ipairs(infos) do
            local level = C_QuestLog.GetQuestDifficultyLevel(info.quest:GetID())
            -- Keep unavailable levels at the end until the quest data arrives.
            if (issecretvalue and issecretvalue(level)) or type(level) ~= "number" or level <= 0 then
                level = math.huge
            end
            levels[info] = level
            positions[info] = index
        end
        table.sort(infos, function(a, b)
            if levels[a] ~= levels[b] then
                return levels[a] < levels[b]
            end
            return positions[a] < positions[b]
        end)
        return infos
    end

    events:UnregisterAllEvents()
    tracker:MarkDirty()
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", InstallQuestSorting)
InstallQuestSorting()
