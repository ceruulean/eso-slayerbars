SlayerBars = SlayerBars or {}
SlayerBars.Util = SlayerBars.Util or {}
local Util = SlayerBars.Util

-- returns left, top, right, bottom, width, height
function Util.GetBounds(control)
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

function Util.FormatPercent(c, m)
    local percent = (c / m) * 100
    if percent < 10 then
        percent = ZO_FastFormatDecimalNumber(ZO_CommaDelimitDecimalNumber(zo_roundToNearest(percent, .1)))
    else
        percent = zo_round(percent)
    end
    return percent
end

function Util.FormatFont(svTable)
    local font = LibMediaProvider:Fetch(LibMediaProvider.MediaType.FONT, svTable[1]) or LibMediaProvider:GetDefault(LibMediaProvider.MediaType.FONT)
    return string.format("%s|%s|%s", font, svTable[2], svTable[3])
end

function Util.CircularTexture(ctrl, texture)
    local cx, cy = ctrl:GetCenter()
    ctrl:SetCircularClip(cx, cy, 39)
    ctrl:SetTexture(texture)
end

function Util.Debounce(fn, delay)
    local active = false
    return function(...)
        if active then return end
        active = true
        fn(...)
        zo_callLater(function() active = false end, delay)
    end
end

local enemyNamePlaceholder = GetString(SI_OPTIONS_ENEMY_NPC_NAMEPLATE_GAMEPAD)
function Util.GetNameOrDefault(unitTag)
    local name = GetUnitName(unitTag)
    return (name and name ~= "") and name or enemyNamePlaceholder
end

--- Chatgpt ramp function lol

local function hexToRgb(hex)
    hex = hex:gsub("#","")
    return {
        r = tonumber(hex:sub(1,2), 16) / 255,
        g = tonumber(hex:sub(3,4), 16) / 255,
        b = tonumber(hex:sub(5,6), 16) / 255
    }
end

local function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X",
        math.floor(math.max(0, math.min(1, r)) * 255 + 0.5),
        math.floor(math.max(0, math.min(1, g)) * 255 + 0.5),
        math.floor(math.max(0, math.min(1, b)) * 255 + 0.5)
    )
end

-- sRGB → linear
local function pivotRgb(n)
    return (n <= 0.04045) and (n / 12.92) or ((n + 0.055) / 1.055) ^ 2.4
end

-- linear → sRGB
local function invPivotRgb(n)
    return (n <= 0.0031308) and (12.92 * n) or (1.055 * (n ^ (1/2.4)) - 0.055)
end

-- RGB → XYZ
local function rgbToXyz(r, g, b)
    r, g, b = pivotRgb(r), pivotRgb(g), pivotRgb(b)
    return
        r*0.4124 + g*0.3576 + b*0.1805,
        r*0.2126 + g*0.7152 + b*0.0722,
        r*0.0193 + g*0.1192 + b*0.9505
end

-- XYZ → LAB
local function xyzToLab(x, y, z)
    local function f(t)
        return (t > 0.008856) and (t^(1/3)) or (7.787*t + 16/116)
    end

    -- D65 reference white
    local xr, yr, zr = x/0.95047, y/1.00000, z/1.08883
    local fx, fy, fz = f(xr), f(yr), f(zr)

    return (116*fy - 16), 500*(fx - fy), 200*(fy - fz)
end

-- LAB → XYZ
local function labToXyz(L, a, b)
    local function fInv(t)
        local t3 = t^3
        return (t3 > 0.008856) and t3 or ((t - 16/116) / 7.787)
    end

    local fy = (L + 16) / 116
    local fx = fy + a / 500
    local fz = fy - b / 200

    local xr, yr, zr = fInv(fx), fInv(fy), fInv(fz)

    return xr*0.95047, yr*1.00000, zr*1.08883
end

-- XYZ → RGB
local function xyzToRgb(x, y, z)
    local r = x* 3.2406 + y*-1.5372 + z*-0.4986
    local g = x*-0.9689 + y* 1.8758 + z* 0.0415
    local b = x* 0.0557 + y*-0.2040 + z* 1.0570

    return invPivotRgb(r), invPivotRgb(g), invPivotRgb(b)
end

-- LAB ↔ LCH
local function labToLch(L, a, b)
    local C = math.sqrt(a*a + b*b)
    local H = math.deg(math.atan2(b, a))
    if H < 0 then H = H + 360 end
    return L, C, H
end

local function lchToLab(L, C, H)
    local Hr = math.rad(H)
    return L, C * math.cos(Hr), C * math.sin(Hr)
end

-- shortest hue interpolation
local function lerpHue(h1, h2, t)
    local dh = h2 - h1
    if math.abs(dh) > 180 then
        dh = dh - 360 * (dh > 0 and 1 or -1)
    end
    return (h1 + dh * t) % 360
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function hexToLch(hex)
    local rgb = hexToRgb(hex)
    local x,y,z = rgbToXyz(rgb.r, rgb.g, rgb.b)
    local L,a,b = xyzToLab(x,y,z)
    return labToLch(L,a,b)
end

local function lchToHex(L,C,H)
    local a,b = lchToLab(L,C,H)
    local x,y,z = labToXyz(L,a,b)
    local r,g,b = xyzToRgb(x,y,z)
    return rgbToHex(r,g,b)
end

function MakeStartColor(hex)
    local L,C,H = hexToLch(hex)

    -- tuned values (feel free to tweak)
    L = L - 28        -- darken
    C = C * 0.95      -- slight desaturation (prevents clipping)

    return lchToHex(L, C, H)
end

-- MAIN FUNCTION
function GenerateLchRamp(startHex, midHex, endHex, steps)
    local result = {}

    local L1,C1,H1 = hexToLch(startHex)
    local L2,C2,H2 = hexToLch(midHex)
    local L3,C3,H3 = hexToLch(endHex)

    local half = math.floor(steps / 2)

    -- start → mid
    for i = 0, half - 1 do
        local t = i / (half - 1)
        local L = lerp(L1, L2, t)
        local C = lerp(C1, C2, t)
        local H = lerpHue(H1, H2, t)
        table.insert(result, lchToHex(L,C,H))
    end

    -- mid → end
    for i = 1, steps - half do
        local t = i / (steps - half)
        local L = lerp(L2, L3, t)
        local C = lerp(C2, C3, t)
        local H = lerpHue(H2, H3, t)
        table.insert(result, lchToHex(L,C,H))
    end

    return result
end