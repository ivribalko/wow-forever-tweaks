-- Include autorun in the native "While moving" camera-turn behavior.
local cameraEvents = CreateFrame("Frame")
local cameraCVar = "GamePadTurnWithCamera"
local elapsedSinceUpdate = 0

local function UpdateCameraTurning()
    -- The movement API includes autorun without inspecting restricted unit speed.
    local value = IsPlayerMoving() and "2" or "0"
    if C_CVar.GetCVar(cameraCVar) ~= value then
        C_CVar.SetCVar(cameraCVar, value)
    end
end

cameraEvents:RegisterEvent("PLAYER_LOGIN")
cameraEvents:RegisterEvent("PLAYER_LOGOUT")
cameraEvents:RegisterEvent("PLAYER_STARTED_MOVING")
cameraEvents:RegisterEvent("PLAYER_STOPPED_MOVING")
cameraEvents:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        self:SetScript("OnUpdate", nil)
        C_CVar.SetCVar(cameraCVar, "0")
        return
    end
    UpdateCameraTurning()
    if event == "PLAYER_LOGIN" then
        -- Poll as well: changes such as landing need not fire movement events.
        self:SetScript("OnUpdate", function(_, elapsed)
            elapsedSinceUpdate = elapsedSinceUpdate + elapsed
            if elapsedSinceUpdate >= 0.05 then
                elapsedSinceUpdate = 0
                UpdateCameraTurning()
            end
        end)
    end
end)
