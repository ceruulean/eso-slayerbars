SlayerBars = SlayerBars
local Utils = SlayerBars.Utils

-- returns left, top, right, bottom, width, height
function Utils.GetControlBounds(control)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    local function visit(ctrl, parentLeft, parentTop)
        if not ctrl:IsHidden() then
            local left, top = ctrl:GetLeft(), ctrl:GetTop()
            local right, bottom = ctrl:GetRight(), ctrl:GetBottom()

            if left and top and right and bottom then
                minX = math.min(minX, left)
                minY = math.min(minY, top)
                maxX = math.max(maxX, right)
                maxY = math.max(maxY, bottom)
            end

            local numChildren = ctrl:GetNumChildren()
            for i = 1, numChildren do
                visit(ctrl:GetChild(i))
            end
        end
    end

    visit(control)

    if minX == math.huge then
        return nil
    end

    return minX, minY, maxX, maxY, maxX - minX, maxY - minY
end

function Utils.FormatPercent(c, m)
    local percent = (c / m) * 100
    if percent < 10 then
        percent = ZO_FastFormatDecimalNumber(ZO_CommaDelimitDecimalNumber(zo_roundToNearest(percent, .1)))
    else
        percent = zo_round(percent)
    end
    return percent
end

function Utils.FormatFont(svTable)
    local font = LibMediaProvider:Fetch(LibMediaProvider.MediaType.FONT, svTable[1]) or LibMediaProvider:GetDefault(LibMediaProvider.MediaType.FONT)
    return string.format("%s|%s|%s", font, svTable[2], svTable[3])
end

function Utils.CircularTexture(ctrl, texture)
    local cx, cy = ctrl:GetCenter()
    ctrl:SetCircularClip(cx, cy, 39)
    ctrl:SetTexture(texture)
end

function Utils.Debounce(fn, delay)
    local active = false
    return function(...)
        if active then return end
        active = true
        fn(...)
        zo_callLater(function() active = false end, delay)
    end
end

function Utils.GetNameOrDefault(unitTag)
    local name = GetUnitName(unitTag)
    return (name and name ~= "") and name or GetString(SI_OPTIONS_ENEMY_NPC_NAMEPLATE_GAMEPAD)
end