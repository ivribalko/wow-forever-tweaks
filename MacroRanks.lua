local _, addon = ...

-- Parse spell operands without changing conditions, resets, or unrelated text.
local function UpgradeOperand(operand, replacements, sequence, preferItems)
    local prefix, rest = operand:match("^(%s*)(.*)$")
    while rest:sub(1, 1) == "[" do
        local conditions, tail = rest:match("^(%b[]%s*)(.*)$")
        if not conditions then return operand end
        prefix, rest = prefix .. conditions, tail
    end
    if sequence then
        local reset, tail = rest:match("^(reset=%S+%s+)(.*)$")
        if reset then prefix, rest = prefix .. reset, tail end
    end
    local bang, spell, trailing = rest:match("^(!*)(.-)(%s*)$")
    if preferItems and C_Item.GetItemInfo(spell) then return operand end
    local name, rank = spell:match("^(.-)%s*(%b())$")
    if not name then return operand end
    local replacement = replacements[(name .. rank):lower()]
    if not replacement then return operand end
    return prefix .. bang .. replacement .. trailing
end

local function UpgradeArguments(arguments, replacements, sequence, preferItems)
    local parts, start, brackets, parentheses = {}, 1, 0, 0
    for index = 1, #arguments + 1 do
        local character = arguments:sub(index, index)
        if character == "[" then brackets = brackets + 1 end
        if character == "]" then brackets = brackets - 1 end
        if brackets == 0 then
            if character == "(" then parentheses = parentheses + 1 end
            if character == ")" then parentheses = parentheses - 1 end
        end
        if index > #arguments or (brackets == 0 and parentheses == 0
            and (character == ";" or (sequence and character == ","))) then
            parts[#parts + 1] = UpgradeOperand(arguments:sub(start, index - 1), replacements, sequence, preferItems)
            parts[#parts + 1] = character
            start = index + 1
        end
    end
    return table.concat(parts)
end

local function MacroCommands()
    local commands = {
        ["#show"] = { preferItems = true }, ["#showtooltip"] = { preferItems = true },
    }
    for _, key in ipairs({ "CAST", "USE", "CASTSEQUENCE", "CASTRANDOM", "USERANDOM" }) do
        local options = {
            sequence = key == "CASTSEQUENCE" or key == "CASTRANDOM" or key == "USERANDOM",
            preferItems = key ~= "CAST",
        }
        commands["/" .. key:lower()] = options
        local index = 1
        while _G["SLASH_" .. key .. index] do
            commands[_G["SLASH_" .. key .. index]:lower()] = options
            index = index + 1
        end
    end
    return commands
end

-- Remove explicit ranks so the game selects the highest learned rank at cast time.
function addon.UpgradeCustomMacroRanks(replacements, isOwned)
    if not next(replacements) then return end
    local commands = MacroCommands()
    local accountCount, characterCount = GetNumMacros()
    local function Upgrade(index)
        if isOwned(index) then return end
        local _, _, body = GetMacroInfo(index)
        if not body then return end
        local updated = body:gsub("[^\r\n]+", function(line)
            local leading, command, spacing, arguments = line:match("^(%s*)(%S+)(%s+)(.*)$")
            local options = command and commands[command:lower()]
            if not options then return line end
            return leading .. command .. spacing
                .. UpgradeArguments(arguments, replacements, options.sequence, options.preferItems)
        end)
        if updated ~= body and #updated <= 255 then
            EditMacro(index, nil, nil, updated)
        end
    end
    for index = 1, accountCount do Upgrade(index) end
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    for index = base + 1, base + characterCount do Upgrade(index) end
end
