-- Cycles chat destinations through isolated D-pad controls while editing chat.
local driver = CreateFrame("Frame")
local owner
local controls = {}
local channels = {}
local dirty = true

local function FocusedChat()
    local edit = GetCurrentKeyBoardFocus()
    local chat = edit and edit.chatFrame
    local utility = GamepadSharedUtility
    if not chat or chat.editBox ~= edit or chat.isTemporary or edit.isGM
        or not edit:IsVisible() or not C_GamePad.IsEnabled()
        or (utility and utility.IsSuspendFooterShown()) then return end
    -- Input focus is the scope of this shortcut. Footer ordering and visibility
    -- describe native navigation, not whether the user is editing this draft.
    return edit
end

local function RefreshChannels()
    channels = {}
    local function Add(kind, label, id)
        channels[#channels + 1] = { kind = kind, label = label, id = id }
    end
    Add("SAY", SAY or "Say")
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then Add("PARTY", PARTY or "Party") end
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then Add("RAID", RAID or "Raid") end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then Add("INSTANCE_CHAT", INSTANCE_CHAT or "Instance") end
    if IsInGuild() then Add("GUILD", GUILD or "Guild") end
    local joined = { GetChannelList() }
    local numbered = {}
    for i = 1, #joined, 3 do
        local id, name, disabled = joined[i], joined[i + 1], joined[i + 2]
        if type(id) == "number" and id > 0 and type(name) == "string" and not disabled then
            numbered[#numbered + 1] = { id = id, name = name }
        end
    end
    table.sort(numbered, function(a, b) return a.id < b.id end)
    for _, channel in ipairs(numbered) do
        Add("CHANNEL", "/" .. channel.id .. " " .. channel.name, channel.id)
    end
    dirty = false
end

local function Destination(edit, direction)
    local kind = edit:GetAttribute("chatType")
    local id = kind == "CHANNEL" and edit:GetChannelTarget()
    for i, channel in ipairs(channels) do
        if channel.kind == kind and (kind ~= "CHANNEL" or channel.id == id) then
            return channels[(i - 1 + direction) % #channels + 1]
        end
    end
    return channels[1]
end

local function Switch(direction)
    if InCombatLockdown() then return end
    local edit = FocusedChat()
    if not edit then return end
    -- Recheck membership at the actual press, including channel renumbering.
    RefreshChannels()
    local destination = Destination(edit, direction)
    if not destination then return end
    owner:SetFrameRef("edit", edit)
    local snippet = string.format([[
        local edit = self:GetFrameRef("edit")
        edit:SetAttribute("chatType", %q)
        edit:SetAttribute("stickyType", %q)
        edit:SetAttribute("channelTarget", %d)
    ]], destination.kind, destination.kind, destination.id or 0)
    -- Write routing attributes in the restricted environment. Header refresh is
    -- visual, but its CHANNEL branch rewrites channelTarget; restore that value
    -- securely afterward. Never invoke native focus or binding-stack methods.
    owner:Execute(snippet)
    edit:UpdateHeader()
    owner:Execute(snippet)
end

local function HideTooltip(control)
    if GameTooltip:IsOwned(control) then GameTooltip:Hide() end
end

local function ShowTooltip(control)
    if not control.destination then return end
    GameTooltip:SetOwner(control, "ANCHOR_TOP")
    GameTooltip:SetText(control.direction < 0 and "Previous Chat Channel" or "Next Chat Channel")
    GameTooltip:AddLine(control.destination, 1, 1, 1, true)
    GameTooltip:AddLine("D-pad Up/Down changes the destination without sending or clearing your draft.", 1, 1, 1, true)
    if InCombatLockdown() then GameTooltip:AddLine("Unavailable in combat.", 1, 0.3, 0.3) end
    GameTooltip:Show()
end

local function Initialize()
    owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    owner:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then self:ClearBindings() end
    ]])
    RegisterStateDriver(owner, "combat", "[combat] combat; peace")
    for i, direction in ipairs({ -1, 1 }) do
        local control = CreateFrame("Button", "ForeverTweaksChatChannel" .. i, UIParent)
        control.direction = direction
        control.key = direction < 0 and "PADDUP" or "PADDDOWN"
        control:SetFrameStrata("TOOLTIP")
        control:SetSize(260, 24)
        local background = control:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.8)
        control:RegisterForClicks("AnyDown")
        control.Icon = control:CreateTexture(nil, "ARTWORK")
        control.Icon:SetSize(24, 24)
        control.Icon:SetPoint("LEFT")
        control.Label = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        control.Label:SetPoint("LEFT", control.Icon, "RIGHT", 5, 0)
        control.Label:SetPoint("RIGHT")
        control.Label:SetJustifyH("LEFT")
        control:SetScript("OnClick", function() Switch(direction) end)
        control:SetScript("OnEnter", ShowTooltip)
        control:SetScript("OnLeave", HideTooltip)
        control:SetScript("OnHide", HideTooltip)
        control:Hide()
        controls[i] = control
    end
end

local function Refresh()
    if not owner then
        if InCombatLockdown() then return end
        Initialize()
    end
    local edit = FocusedChat()
    if dirty then RefreshChannels() end
    local left, top = edit and edit:GetLeft(), edit and edit:GetTop()
    local visible = edit and left and top
    local enabled = visible and not InCombatLockdown() and #channels > 1
    for i, control in ipairs(controls) do
        if visible then
            local destination = Destination(edit, control.direction)
            control.destination = destination and destination.label
            control.Label:SetText((control.direction < 0 and "Previous: " or "Next: ") .. (control.destination or "Say"))
            local atlas = InputIconTextureSetUtility.GetNormalActiveInputIconButtonTexture(control.key)
            if atlas then control.Icon:SetAtlas(atlas) end
            local scale = edit:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local width = math.max(1, (edit:GetWidth() * scale - 4) / 2)
            control:SetWidth(width)
            control:ClearAllPoints()
            control:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale + (i - 1) * (width + 4), top * scale + 2)
            control:SetAlpha(enabled and 1 or 0.4)
        end
        control:SetShown(not not visible)
        if GameTooltip:IsOwned(control) then ShowTooltip(control) end
    end
    if InCombatLockdown() then return end
    if enabled then
        for _, control in ipairs(controls) do
            local name = control:GetName()
            if GetBindingAction(control.key, true) ~= "CLICK " .. name .. ":LeftButton" then
                owner:Execute(string.format("self:SetBindingClick(true, %q, %q, 'LeftButton')", control.key, name))
            end
        end
    else
        owner:Execute("self:ClearBindings()")
    end
end

for _, event in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "CHANNEL_UI_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function() dirty = true end)
driver:SetScript("OnUpdate", function()
    if IsLoggedIn() then Refresh() end
end)
