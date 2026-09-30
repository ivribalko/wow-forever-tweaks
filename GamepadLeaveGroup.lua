-- Offers target invitations or leave-group confirmation in the shortcuts slot.
local driver = CreateFrame("Frame")
local shortcuts, prompt, promptAnchor
local buttonPending = true
local confirmationData

-- Do not add a dialog definition to StaticPopupDialogs: native gamepad popup
-- initialization reads that definition before updating protected focus state.
local function HideConfirmation()
    local data = confirmationData
    confirmationData = nil
    if data then securecallfunction(StaticPopup_Hide, "GENERIC_CONFIRMATION", data) end
end

-- A friendly player keeps invite mode even when already grouped, so an
-- unavailable invitation never silently becomes a leave-group action.
local function GetShortcutAction()
    local player = UnitIsPlayer("target")
    local friendly = UnitIsFriend("player", "target")
    local selfTarget = UnitIsUnit("player", "target")
    if not issecretvalue(player) and not issecretvalue(friendly)
        and not issecretvalue(selfTarget) and player and friendly and not selfTarget then
        local party, raid = UnitInParty("target"), UnitInRaid("target")
        local name = GetUnitName("target", true)
        local available = not issecretvalue(party) and not issecretvalue(raid)
            and not party and not raid
            and not issecretvalue(name) and name ~= nil
        return true, available, name
    end
    return false, IsInGroup()
end

local function ShowConfirmation()
    if confirmationData then return end
    local data = {
        text = "Leave your current group?",
        acceptText = YES,
        cancelText = CANCEL,
    }
    data.callback = function()
        if confirmationData ~= data then return end
        confirmationData = nil
        local invite, available = GetShortcutAction()
        if not invite and available then C_PartyInfo.LeaveParty() end
    end
    data.cancelCallback = function()
        if confirmationData == data then confirmationData = nil end
    end
    confirmationData = data
    -- Use the native GENERIC_CONFIRMATION definition and controller lifecycle.
    -- The boundary alone was insufficient with an addon-owned definition.
    securecallfunction(StaticPopup_ShowCustomGenericConfirmation, data)
end

local function OnLeaveClick(_, _, down)
    -- Both-shoulder mode already cancels native targeting. Do not write its
    -- wasModifierUsed field: native protected targeting code reads it later.
    if not down then return end
    local invite, available, name = GetShortcutAction()
    if not available then return end
    if invite then
        C_PartyInfo.InviteUnit(name)
    else
        ShowConfirmation()
    end
end

local function RefreshButton()
    buttonPending = true
    if not shortcuts or InCombatLockdown() then return end
    local button = shortcuts.faceBottomButton
    button:SetScript("OnClick", OnLeaveClick)
    local invite, available = GetShortcutAction()
    button.SpecialActionIcon:SetTexture(invite and "Interface\\Icons\\Spell_Holy_DevotionAura"
        or "Interface\\Icons\\Spell_Shadow_Teleport")
    button.SpecialActionIcon:Show()
    shortcuts:SetButtonEnabled(button, available)
    buttonPending = false
end

local function RefreshPrompt(entry)
    local invite, available = GetShortcutAction()
    entry:SetPromptText(invite and "Invite Target" or (PARTY_LEAVE or "Leave Party"))
    entry:EnableOrDisablePrompt(available)
end

local function Install()
    local page = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    if not shortcuts and page and page.actionBars and page.actionBars.shortcutsBar
        and page.actionBars.shortcutsBar.faceBottomButton and not InCombatLockdown() then
        shortcuts = page.actionBars.shortcutsBar
        RefreshButton()
    end

    local legend = GamepadPersistentInputLegend
    if not prompt and legend and legend.groups and legend.groups.MODIFIER then
        -- Never call CreateEntry/AddToGroup here. Inserting into groups taints
        -- native legend iteration in the shared core-binding callback chain.
        -- An independent prompt follows an existing row without joining it.
        local bagsEntry
        for _, entry in ipairs(legend.groups.MODIFIER) do
            if entry.InputIcon1 and entry.InputIcon1.mappedButtonKey == GAMEPAD_FACE_RIGHT then
                bagsEntry = entry
                break
            end
        end
        if bagsEntry then
            prompt = CreateFrame("Frame", nil, legend, "InputPromptOneIconWithTextTemplate")
            prompt:SetPromptInputIconKey(1, GAMEPAD_FACE_BOTTOM)
            prompt:SetPromptText(PARTY_LEAVE or "Leave Party")
            prompt:SetPromptFont("GameFontNormal")
            prompt:SetInputIconSize(1, 18, 18)
            prompt:SetPoint("TOPLEFT", bagsEntry, "TOPLEFT", 0, -24)
            prompt:SetShown(bagsEntry:IsShown())
            promptAnchor = bagsEntry
            RefreshPrompt(prompt)
        end
    end
    -- Native setup can reset or swap the bottom-face button. Observe its
    -- handler after native updates, without hooking an inherited method.
    if shortcuts and (buttonPending
        or shortcuts.faceBottomButton:GetScript("OnClick") ~= OnLeaveClick) then
        RefreshButton()
    end
    if prompt and promptAnchor then
        local visible = promptAnchor:IsVisible()
        if visible and not prompt:IsShown() then RefreshPrompt(prompt) end
        prompt:SetShown(visible)
    end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("GROUP_ROSTER_UPDATE")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("UNIT_FACTION")
driver:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_TARGET_CHANGED" or event == "UNIT_FACTION" then
        -- Dismiss stale confirmations when the roster or selected action changes.
        HideConfirmation()
        buttonPending = true
        if prompt then RefreshPrompt(prompt) end
    end
    Install()
end)

-- Follow native setup and helper visibility without running addon callbacks
-- inside native button-setup or helper show/hide paths.
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    Install()
end)
