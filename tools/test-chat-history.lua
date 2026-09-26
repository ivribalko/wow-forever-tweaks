-- Exercises reload persistence and native whisper-window lifecycle with mocked APIs.
local driver
local friends = {}
local combat = false
function CreateFrame()
    driver = { RegisterEvent = function() end, UnregisterEvent = function() end,
        SetScript = function(self, _, fn) self.handler = fn end }
    return driver
end
function InCombatLockdown() return combat end
function BNGetNumFriends() return #friends end
C_BattleNet = { GetFriendAccountInfo = function(index) return friends[index] end }
function GetChatWindowInfo() return "General" end
local function fire(event, reload) driver:handler(event, false, reload) end
local function frame(name, chatType, target)
    local f = { chatType = chatType, chatTarget = target, isTemporary = chatType ~= nil,
        inUse = true, messages = {} }
    function f:GetID() return 1 end
    function f:GetNumMessages() return #self.messages end
    function f:GetMaxLines() return 120 end
    function f:GetMessageInfo(i) return table.unpack(self.messages[i]) end
    function f:BackFillMessage(...) table.insert(self.messages, 1, {...}) end
    _G[name] = f
    CHAT_FRAMES[#CHAT_FRAMES + 1] = name
    return f
end
local function reset()
    CHAT_FRAMES = {}
    ChatFrame2 = {}
    frame("ChatFrame1")
    assert(loadfile("ChatHistory.lua"))()
end
function FCF_OpenTemporaryWindow(kind, target, source, selectWindow)
    assert(source == nil and selectWindow == false)
    return frame("Temp" .. #CHAT_FRAMES, kind, target)
end
reset()
local open = frame("Open", "WHISPER", "Recipient")
for i = 1, 130 do open.messages[i] = {tostring(i), 1, 0.5, 0} end
local closed = frame("Closed", "WHISPER", "ClosedRecipient")
closed.inUse = false
friends = {{ accountName = "|Kold|k", battleTag = "Recipient#0000" }}
frame("BattleNet", "BN_WHISPER", "|Kold|k").messages = {{"|HBNplayer:old|h|Kold|k|h: hello", 1, 1, 1}}
fire("PLAYER_LOGOUT")
assert(#ForeverTweaksChatHistory.whispers == 2)
reset()
friends = {}
combat = true
fire("PLAYER_ENTERING_WORLD", true)
assert(#CHAT_FRAMES == 1)
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(#CHAT_FRAMES == 2)
assert(Temp1.chatTarget == "Recipient" and #Temp1.messages == 120)
assert(Temp1.messages[1][1] == "11" and Temp1.messages[120][1] == "130")
friends = {{ accountName = "|Knew|k", battleTag = "Recipient#0000" }}
fire("BN_FRIEND_INFO_CHANGED")
assert(#CHAT_FRAMES == 3 and Temp2.chatTarget == "|Knew|k")
assert(Temp2.messages[1][1] == "|Knew|k: hello")
fire("BN_FRIEND_INFO_CHANGED")
assert(#CHAT_FRAMES == 3)
Temp1.inUse = false
fire("PLAYER_LOGOUT")
assert(#ForeverTweaksChatHistory.whispers == 1)
reset()
fire("PLAYER_ENTERING_WORLD", false)
assert(ForeverTweaksChatHistory == nil and #CHAT_FRAMES == 1)
print("chat history lifecycle tests passed")
