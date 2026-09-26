local MAX_MESSAGES = 120

local function IsPlain(value, expectedType)
    return not (issecretvalue and issecretvalue(value)) and type(value) == expectedType
end

local function IsPersistentChat(frame)
    return frame and frame ~= ChatFrame2 and not frame.isTemporary
        and frame.GetMessageInfo and frame.BackFillMessage
end

local function SaveHistory()
    local history = {}
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if IsPersistentChat(frame) then
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
            history[frameName] = {
                name = GetChatWindowInfo(frame:GetID()),
                messages = messages,
            }
        end
    end
    ForeverTweaksChatHistory = history
end

local function RestoreHistory()
    local history = ForeverTweaksChatHistory
    ForeverTweaksChatHistory = nil
    if type(history) ~= "table" then return end

    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        local saved = history[frameName]
        if IsPersistentChat(frame) and type(saved) == "table"
            and saved.name == GetChatWindowInfo(frame:GetID())
            and type(saved.messages) == "table" then
            local messages = saved.messages
            local available = math.max(0, frame:GetMaxLines() - frame:GetNumMessages())
            -- Backfill newest first, behind messages received during UI loading.
            for index = #messages, math.max(1, #messages - math.min(MAX_MESSAGES, available) + 1), -1 do
                local message = messages[index]
                if type(message) == "table" and IsPlain(message[1], "string")
                    and IsPlain(message[2], "number") and IsPlain(message[3], "number")
                    and IsPlain(message[4], "number") then
                    frame:BackFillMessage(message[1], message[2], message[3], message[4])
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, _, isReloadingUI)
    if event == "PLAYER_LOGOUT" then
        SaveHistory()
    else
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if isReloadingUI then
            RestoreHistory()
        else
            ForeverTweaksChatHistory = nil
        end
    end
end)
