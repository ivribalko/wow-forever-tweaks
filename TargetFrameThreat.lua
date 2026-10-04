-- Trace player threat relative to the highest reported threat inside the target badge.
local fill, sweep, levelCircle

local function ReadableNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end

local function UpdateThreat()
    if not fill then
        return
    end
    fill:Hide()
    if not TargetFrame:IsShown() or not levelCircle:IsShown()
        or not UnitExists("target") or UnitIsPlayer("target")
        or not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target") then
        return
    end

    local _, status, _, percent, playerThreat = UnitDetailedThreatSituation("player", "target")
    if not ReadableNumber(playerThreat) or playerThreat <= 0 then
        return
    end

    local highest = playerThreat
    -- Raw percentage references the current tank, which need not have the most threat.
    if ReadableNumber(percent) and percent > 0 then
        highest = math.max(highest, playerThreat * 100 / percent)
    end
    local function IncludeUnit(unit)
        local _, _, _, _, threat = UnitDetailedThreatSituation(unit, "target")
        if ReadableNumber(threat) then
            highest = math.max(highest, threat)
        end
    end
    IncludeUnit("targettarget")
    IncludeUnit("pet")
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            IncludeUnit("raid" .. index)
            IncludeUnit("raidpet" .. index)
        end
    else
        for index = 1, GetNumSubgroupMembers() do
            IncludeUnit("party" .. index)
            IncludeUnit("partypet" .. index)
        end
    end

    local progress = math.min(playerThreat / highest, 1)
    -- Match the fill's comparison, with native secure-tanking status taking priority.
    if ReadableNumber(status) and status == 3 then
        fill:SetVertexColor(1, 0.15, 0.1, 1)
    elseif progress >= 0.9 or (ReadableNumber(status) and status >= 1) then
        fill:SetVertexColor(1, 0.5, 0, 1)
    elseif progress >= 0.7 then
        fill:SetVertexColor(1, 0.85, 0, 1)
    else
        fill:SetVertexColor(0.2, 0.85, 0.2, 1)
    end
    sweep:SetFromPercent(progress)
    sweep:SetToPercent(progress)
    fill:Show()
end

local function InitializeThreat()
    if fill then
        return
    end
    local content = TargetFrame and TargetFrame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    levelCircle = main and main.LevelBackgroundCircle
    if not levelCircle then
        return
    end

    -- Only addon-owned artwork is changed; native level, skull, and focus state stay intact.
    fill = main:CreateTexture(nil, "OVERLAY", nil, 6)
    fill:SetTexture("Interface\\AddOns\\ForeverTweaks\\XPRing")
    fill:SetRotation(math.pi)
    if fill.SetRadialProgressBarFeather then
        fill:SetRadialProgressBarFeather(0.001)
    end
    fill:SetPoint("TOPLEFT", levelCircle, "TOPLEFT", 6, -6)
    fill:SetPoint("BOTTOMRIGHT", levelCircle, "BOTTOMRIGHT", -6, 6)
    local group = fill:CreateAnimationGroup()
    sweep = group:CreateAnimation("RadialProgress")
    sweep:SetDuration(1)
    sweep:SetFromPercent(0)
    sweep:SetToPercent(0)
    group:SetLooping("REPEAT")
    group:Play()
    fill:Hide()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
    "PLAYER_TARGET_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "GROUP_ROSTER_UPDATE", "UNIT_PET" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    InitializeThreat()
    UpdateThreat()
end)
-- Follow native badge visibility and threat updates without hooking target-frame methods.
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.05 then
        elapsed = 0
        UpdateThreat()
    end
end)
