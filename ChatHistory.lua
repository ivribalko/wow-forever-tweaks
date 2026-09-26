local MAX_MESSAGES = 120

local function IsPlain(value, expectedType)
    return not (issecretvalue and issecretvalue(value)) and type(value) == expectedType
end

local function IsPersistentChat(frame)
    return frame and frame ~= ChatFrame2 and not frame.isTemporary
        and frame.GetMessageInfo and frame.BackFillMessage
end

local pendingWhispers = {}

local function IsWhisper(frame)
    return frame and frame.isTemporary and frame.inUse
        and IsPlain(frame.chatType, "string")
        and (frame.chatType == "WHISPER" or frame.chatType == "BN_WHISPER")
        and IsPlain(frame.chatTarget, "string")
end

local function FindFriend(field, value)
    if not C_BattleNet or not BNGetNumFriends then return end
    for index = 1, BNGetNumFriends() do
        local info = C_BattleNet.GetFriendAccountInfo(index)
        if info and IsPlain(info[field], "string") and info[field] == value then
            return info
        end
    end
end

local function RestoreMessages(frame, messages, oldTarget, newTarget)
    if type(messages) ~= "table" then return end
    local available = math.max(0, frame:GetMaxLines() - frame:GetNumMessages())
    for index = #messages, math.max(1, #messages - math.min(MAX_MESSAGES, available) + 1), -1 do
        local message = messages[index]
        if type(message) == "table" and IsPlain(message[1], "string")
            and IsPlain(message[2], "number") and IsPlain(message[3], "number")
            and IsPlain(message[4], "number") then
            local text = message[1]
            -- Battle.net links and opaque name tokens belong to the old UI session.
            text = text:gsub("|HBNplayer:[^|]*|h(.-)|h", "%1")
            text = text:gsub("|K.-|k", function(token)
                if token == oldTarget then return newTarget end
                return "[Battle.net]"
            end)
            frame:BackFillMessage(text, message[2], message[3], message[4])
        end
    end
end

local function RestoreWhispers()
    if InCombatLockdown() then return end
    for index = #pendingWhispers, 1, -1 do
        local saved = pendingWhispers[index]
        local target = saved.target
        if saved.chatType == "BN_WHISPER" then
            local info = FindFriend("battleTag", saved.battleTag)
            target = info and info.accountName
        end
        if IsPlain(target, "string") and target ~= "" then
            local frame
            for _, name in ipairs(CHAT_FRAMES or {}) do
                local candidate = _G[name]
                if IsWhisper(candidate) and candidate.chatType == saved.chatType
                    and candidate.chatTarget == target then
                    frame = candidate
                    break
                end
            end
            frame = frame or FCF_OpenTemporaryWindow(saved.chatType, target, nil, false)
            if frame then
                RestoreMessages(frame, saved.messages, saved.target, target)
                table.remove(pendingWhispers, index)
            end
        end
    end
end

local function SaveHistory()
    local history = { whispers = {} }
    for _, saved in ipairs(pendingWhispers) do
        history.whispers[#history.whispers + 1] = saved
    end
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if IsPersistentChat(frame) or IsWhisper(frame) then
            local messages = {}
            local count = frame:GetNumMessages()
            for index = math.max(1, count - MAX_MESSAGES + 1), count do
                local text, r, g, b = frame:GetMessageInfo(index)
                -- Restricted values cannot be serialized. Session-specific access IDs
                -- and line IDs are deliberately omitted from restored messages.
                if IsPlain(text, "string") and IsPlain(r, "number")
                    and IsPlain(g, "number") and IsPlain(b, "number") then
                    messages[#messages + 1] = {text, r, g, b}
                end
            end
            if IsWhisper(frame) then
                local info = frame.chatType == "BN_WHISPER"
                    and FindFriend("accountName", frame.chatTarget)
                if frame.chatType == "WHISPER" or (info and IsPlain(info.battleTag, "string") and info.battleTag ~= "") then
                    history.whispers[#history.whispers + 1] = {
                        chatType = frame.chatType, target = frame.chatTarget,
                        battleTag = info and info.battleTag, messages = messages,
                    }
                end
            else
                history[frameName] = {
                    name = GetChatWindowInfo(frame:GetID()), messages = messages,
                }
            end
        end
    end
    ForeverTweaksChatHistory = history
end

local function RestoreHistory()
    local history = ForeverTweaksChatHistory
    ForeverTweaksChatHistory = nil
    if type(history) ~= "table" then return end

    if type(history.whispers) == "table" then
        for _, saved in ipairs(history.whispers) do
            if type(saved) == "table" and IsPlain(saved.target, "string")
                and (saved.chatType == "WHISPER" or
                    (saved.chatType == "BN_WHISPER" and IsPlain(saved.battleTag, "string"))) then
                pendingWhispers[#pendingWhispers + 1] = saved
            end
        end
    end
    RestoreWhispers()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        local saved = history[frameName]
        if IsPersistentChat(frame) and type(saved) == "table"
            and saved.name == GetChatWindowInfo(frame:GetID())
            and type(saved.messages) == "table" then
            RestoreMessages(frame, saved.messages)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("BN_FRIEND_INFO_CHANGED")
events:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, _, isReloadingUI)
    if event == "PLAYER_LOGOUT" then
        SaveHistory()
    elseif event ~= "PLAYER_ENTERING_WORLD" then
        RestoreWhispers()
    else
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if isReloadingUI then
            RestoreHistory()
        else
            ForeverTweaksChatHistory = nil
        end
    end
end)
