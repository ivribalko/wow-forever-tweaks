-- Offers target invitations in shortcuts and immediate group leaving for the wheel.
local driver = CreateFrame("Frame")
local shortcuts, prompt
local buttonPending = true
-- The shortcut only invites friendly players outside the current group.
local function GetInviteTarget()
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
        return available, name
    end
    return false
end

local function LeaveParty()
    if IsInGroup() then C_PartyInfo.ConfirmLeaveParty() end
end

-- Secure Share release calls this addon-owned method after closing the wheel.
local leaveRequest = CreateFrame("Button", "ForeverTweaksLeaveGroupRequest", UIParent)
leaveRequest:EnableMouse(false)
leaveRequest.LeaveParty = LeaveParty

local function OnInviteClick(_, _, down)
    -- Both-shoulder mode already cancels native targeting. Do not write its
    -- wasModifierUsed field: native protected targeting code reads it later.
    if not down then return end
    local available, name = GetInviteTarget()
    if not available then return end
    C_PartyInfo.InviteUnit(name)
end

local function RefreshButton()
    buttonPending = true
    if not shortcuts or InCombatLockdown() then return end
    local button = shortcuts.faceBottomButton
    button:SetScript("OnClick", OnInviteClick)
    local available = GetInviteTarget()
    button.SpecialActionIcon:SetTexture("Interface\\Icons\\Spell_Holy_DevotionAura")
    button.SpecialActionIcon:Show()
    shortcuts:SetButtonEnabled(button, available)
    buttonPending = false
end

local function RefreshPrompt(entry)
    local available = GetInviteTarget()
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
        -- An unprotected child inherits row visibility immediately.
        local bagsEntry
        for _, entry in ipairs(legend.groups.MODIFIER) do
            if entry.InputIcon1 and entry.InputIcon1.mappedButtonKey == GAMEPAD_FACE_RIGHT then
                bagsEntry = entry
                break
            end
        end
        if bagsEntry then
            prompt = CreateFrame("Frame", nil, bagsEntry, "InputPromptOneIconWithTextTemplate")
            prompt:SetPromptInputIconKey(1, GAMEPAD_FACE_BOTTOM)
            prompt:SetPromptText("Invite Target")
            prompt:SetPromptFont("GameFontNormal")
            prompt:SetInputIconSize(1, 18, 18)
            prompt:SetPoint("TOPLEFT", bagsEntry, "TOPLEFT", 0, -24)
            RefreshPrompt(prompt)
        end
    end
    -- Native setup can reset or swap the bottom-face button. Observe its
    -- handler after native updates, without hooking an inherited method.
    if shortcuts and (buttonPending
        or shortcuts.faceBottomButton:GetScript("OnClick") ~= OnInviteClick) then
        RefreshButton()
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
        buttonPending = true
        if prompt then RefreshPrompt(prompt) end
    end
    Install()
end)

-- Observe native button resets each frame without hooking native setup.
-- Prompt visibility comes directly from its unprotected parent row.
driver:SetScript("OnUpdate", Install)
