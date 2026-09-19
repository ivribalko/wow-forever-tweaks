-- Cycle the active quest in tracker order, following UITweaks.
local function GetWatchedQuestIDs()
    local watchedQuestIDs = {}
    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if questID then
            watchedQuestIDs[#watchedQuestIDs + 1] = questID
        end
    end

    local orderedQuestIDs = {}
    for _, name in ipairs({ "CampaignQuestObjectiveTracker", "QuestObjectiveTracker" }) do
        local module = _G[name]
        if module and module.BuildQuestWatchInfos then
            for _, info in ipairs(module:BuildQuestWatchInfos()) do
                local quest = info.quest
                local questID = quest and quest.GetID and quest:GetID()
                if questID then
                    orderedQuestIDs[#orderedQuestIDs + 1] = questID
                end
            end
        end
    end
    return #orderedQuestIDs > 0 and orderedQuestIDs or watchedQuestIDs
end

local function SelectQuest(direction)
    local questIDs = GetWatchedQuestIDs()
    if #questIDs == 0 then
        return
    end
    local activeQuestID = C_SuperTrack.GetSuperTrackedQuestID()
    local selectedIndex = direction == 1 and 1 or #questIDs
    for index, questID in ipairs(questIDs) do
        if questID == activeQuestID then
            selectedIndex = (index - 1 + direction) % #questIDs + 1
            break
        end
    end
    C_SuperTrack.SetSuperTrackedQuestID(questIDs[selectedIndex])
end

SLASH_FOREVERTWEAKSNEXTQUEST1 = "/ftnextquest"
SlashCmdList.FOREVERTWEAKSNEXTQUEST = function() SelectQuest(1) end
SLASH_FOREVERTWEAKSPREVQUEST1 = "/ftprevquest"
SlashCmdList.FOREVERTWEAKSPREVQUEST = function() SelectQuest(-1) end

local macros = {
    { name = "Quest Next", body = "/ftnextquest" },
    { name = "Quest Prev", body = "/ftprevquest" },
}

-- Create account macros automatically; protected macro writes wait for combat to end.
local events = CreateFrame("Frame")
local warnedAboutSpace = false
local function EnsureMacros()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local missing = false
    for _, macro in ipairs(macros) do
        local index = GetMacroIndexByName(macro.name)
        if index and index > 0 then
            local _, _, body = GetMacroInfo(index)
            if body ~= macro.body then
                EditMacro(index, macro.name, "INV_Misc_Note_01", macro.body)
            end
        else
            local count = GetNumMacros()
            local limit = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS
                or MAX_ACCOUNT_MACROS or 120
            if count < limit then
                CreateMacro(macro.name, "INV_Misc_Note_01", macro.body, false)
            else
                missing = true
            end
        end
    end
    if missing then
        events:RegisterEvent("UPDATE_MACROS")
        if not warnedAboutSpace then
            print("Forever Tweaks: Free account macro slots to create Quest Next and Quest Prev automatically.")
            warnedAboutSpace = true
        end
    else
        events:UnregisterEvent("UPDATE_MACROS")
        warnedAboutSpace = false
    end
end

-- Macro writes can emit UPDATE_MACROS synchronously.
local ensuringMacros = false
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if ensuringMacros then return end
    ensuringMacros = true
    EnsureMacros()
    ensuringMacros = false
end)
