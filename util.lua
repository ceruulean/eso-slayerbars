SlayerBars = SlayerBars
SlayerBars.Util = {}

-- returns left, top, right, bottom, width, height
function SlayerBars.Util.GetControlBounds(control)
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