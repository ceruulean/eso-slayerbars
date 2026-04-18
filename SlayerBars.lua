SlayerBars = SlayerBars or {}
local SB = SlayerBars
local LMP = LibMediaProvider

SB.is_unlocked = false
SB.Anim = {}
SB.instantiatedBars = {}
-- Modules --
SlayerBars.Util = {}
local Util = SlayerBars.Util
SlayerBars.UI = {}

SB.primary_bar_frag = nil
SB.other_bars_frag = nil
local boss1 = "boss1"
local PRIMARY_BAR = nil
local crosshairEnabled = true

local EPSILON = 0.0001
local PEEL_COLORS_COUNT = 10

local PEEL_COLORS_PURPLE = {
    ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH],
    {ZO_ColorDef:New("ba280f"), ZO_ColorDef:New("E33F2A")},
    {ZO_ColorDef:New("c23b11"), ZO_ColorDef:New("EB5123")},
    {ZO_ColorDef:New("bf5424"), ZO_ColorDef:New("F2641B")},
    {ZO_ColorDef:New("d46120"), ZO_ColorDef:New("F97813")},
    {ZO_ColorDef:New("ba4634"), ZO_ColorDef:New("f2666f")},
    {ZO_ColorDef:New("d15e7f"), ZO_ColorDef:New("f55683")},
    {ZO_ColorDef:New("b05aa6"), ZO_ColorDef:New("d952c9")},
    {ZO_ColorDef:New("5A26AD"), ZO_ColorDef:New("8E47A8")},
    {ZO_ColorDef:New("4822D4"), ZO_ColorDef:New("8530DA")},
}

local PEEL_COLORS_Handpicked = {
    ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH], -- #722323, #da3030, DeltaE: 21.51
    {ZO_ColorDef:New("c94024"), ZO_ColorDef:New("e63535")},
    {ZO_ColorDef:New("ea6029"), ZO_ColorDef:New("f55842")},
    {ZO_ColorDef:New("f07424"), ZO_ColorDef:New("f57138")},
    {ZO_ColorDef:New("f5881f"), ZO_ColorDef:New("f7a34f")},
    {ZO_ColorDef:New("f89b1c"), ZO_ColorDef:New("ffb754")},
    {ZO_ColorDef:New("faae1c"), ZO_ColorDef:New("ffc04d")},
    {ZO_ColorDef:New("fac121"), ZO_ColorDef:New("facd50")},
    {ZO_ColorDef:New("FFD721"), ZO_ColorDef:New("FFE35E")},
    {ZO_ColorDef:New("f7e739"), ZO_ColorDef:New("f2e76b")}
}

local PEEL_COLORS = {
    ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH], -- #722323, #da3030, DeltaE: 21.51
    {ZO_ColorDef:New("7a2623"), ZO_ColorDef:New("e0442e")},
    {ZO_ColorDef:New("833024"), ZO_ColorDef:New("e45a2c")},
    {ZO_ColorDef:New("8c3b24"), ZO_ColorDef:New("e86f28")},
    {ZO_ColorDef:New("954726"), ZO_ColorDef:New("eb8426")},
    {ZO_ColorDef:New("9e5327"), ZO_ColorDef:New("ee9425")},
    {ZO_ColorDef:New("a76029"), ZO_ColorDef:New("f0a827")},
    {ZO_ColorDef:New("b06d2c"), ZO_ColorDef:New("f2b92e")},
    {ZO_ColorDef:New("b97931"), ZO_ColorDef:New("f3c53a")},
    {ZO_ColorDef:New("c28537"), ZO_ColorDef:New("f4c847")},
}

local StackedBar = ZO_Object:Subclass()

function StackedBar:New(...)
    local manager = ZO_Object.New(self)
    manager:Initialize(...)
    return manager
end

function StackedBar:Initialize(unitTag, existingControl, parentControl)
    self.unitTag = unitTag
    self.control =
        existingControl or
        CreateControlFromVirtual(ZO_Gamepad_TempVirtualKeyboardGenRandomString("SB", 9), parentControl or SlayerBar, "SlayerBarStatusTemplate")
    local ctrl = self.control

    self.bar = ctrl:GetNamedChild("Bar")
    self.barWidth = self.bar:GetWidth()
    self.resourceNumbers = ctrl:GetNamedChild("ResourceNumbers")
    self.resourceNumberFormat = RESOURCE_NUMBERS_SETTING_OFF
    self.bgBackdrop = ctrl:GetNamedChild("BgBackdrop")

    self.backlayer = ctrl:GetNamedChild("Backlayer")
    self.stacksLabel = ctrl:GetNamedChild("StacksLabel")
    self.unitName = Util.GetNameOrDefault(unitTag)
    self.nameLabel = ctrl:GetNamedChild("NameLabel")

    self.barContainer = ctrl:GetNamedChild("BarContainer")
    self.overlay = ctrl:GetNamedChild("FlashOverlay")
    self.overlayScrollAnim = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsScroll", self.overlay)
    
    self.peelColors = PEEL_COLORS
    -- self.overlayScrollAnim:GetAnimation(1):SetDuration(5000)
end

function StackedBar:RegisterUnit(unitTag)
    self:Unregister()
    self.unitTag = unitTag
    local controlName = self.control:GetName()
    self.eventNamespace = self.eventNamespace or "SB_" .. controlName
    if unitTag ~= nil then
        self.onPowerUpdateHandler =
            ZO_MostRecentPowerUpdateHandler:New(
            self.eventNamespace,
            function(...)
                self:OnPowerUpdate(...)
            end
        )
        self.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
        self.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, unitTag)
    end
    self.control:RegisterForEvent(
        EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
        function(...)
            self:OnUnitAttributeVisualAdded(...)
        end
    )
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, unitTag)
    self.control:RegisterForEvent(
        EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
        function(...)
            self:OnUnitAttributeVisualUpdated(...)
        end
    )
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, unitTag)
    self.control:RegisterForEvent(
        EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,
        function(...)
            self:OnUnitAttributeVisualRemoved(...)
        end
    )
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, unitTag)
end

function StackedBar:Unregister()
    if self.eventNamespace then
        EVENT_MANAGER:UnregisterForEvent(self.eventNamespace, EVENT_POWER_UPDATE)
    end
    self.onPowerUpdateHandler = nil
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
    self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
end

function StackedBar:ImpactShake()
    self.shakeAnim:PlayFromStart()
    self.flashAnim:PlayFromStart()
end

function StackedBar:EnableLeadshine()
    self.leadshine = self.leadshine or self.control:GetNamedChild("Leadshine")
    self.leadshineIdle = self.leadshineIdle or ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsLeadingShineIdle", self.leadshine)
    self.leadshine:SetHidden(false)
    self.leadshineIdle:PlayFromStart()
    self.leadshineHitAnim = self.leadshineHitAnim or ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsHitIndicatorAnimation", self.leadshine)
    self.leadHit = self.leadHit or 
        Util.Debounce(function()
            self.leadshineHitAnim:PlayFromStart()
        end, 800)
end

function StackedBar:DisableLeadshine()
    if self.leadshine then self.leadshine:SetHidden(true) end
end

function StackedBar:LeadIsHidden()
    return (not self.leadshine or self.leadshine:IsHidden())
end

function StackedBar:SetStacks(count)
    self.stacks = count
end

function StackedBar:OnPowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if unitTag ~= self.unitTag then
        return
    end
    if self._lastPowerMax ~= powerMax then
        -- self._lastUnitName = self.unitName
        self:SetMinMax(0, powerMax)
    end
    self.uavInfo = {GetAllUnitAttributeVisualizerEffectInfo(unitTag)}
    -- { uav, statType, attributeType, powerType, value, maxValue }
    if self.uavInfo[1] == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
        self.uavInvuln = true
        self:SetInvulnVisual()
    else
        self.uavInvuln = false
    end
    self:SetValue(powerValue)
end

function StackedBar:SetMinMax(mn, mx)
    self.powerMax = mx or 1
    self._lastPowerMax = self.powerMax
    self.bar:SetMinMax(mn, self.powerMax)
end

function StackedBar:SetResourceFormat(enum)
    self.resourceNumberFormat = enum
    self.resourceNumbers:SetHidden(enum == RESOURCE_NUMBERS_SETTING_OFF)
    self:SetValue(self.bar:GetValue(), true)
end

local g_animationPool
local DEFAULT_ANIMATION_TIME_MS = 500

local function OnAnimationTransitionUpdate(animation, progress)
    local ctrl = animation.ctrl
    if not ctrl then
        return
    end
    local initialValue = animation.initialValue
    local endValue = animation.endValue
    local newBarValue = zo_lerp(initialValue, endValue, progress)
    ctrl:ClearAnchors()
    ctrl:SetAnchor(CENTER, animation.parent, LEFT, newBarValue, 0)
end

local function OnStopAnimation(animation, completedPlaying)
    local ctrl = animation:GetFirstAnimation().ctrl
    ctrl.animation = nil
    g_animationPool:ReleaseObject(animation.key)

    if ctrl.onStopCallback then
        ctrl.onStopCallback(ctrl, completedPlaying)
    end
end

local function AcquireAnimation()
    if not g_animationPool then
        local function Factory(objectPool)
            local animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_StatusBarGrowTemplate")
            animation:GetFirstAnimation():SetUpdateFunction(OnAnimationTransitionUpdate)
            animation:SetHandler("OnStop", OnStopAnimation)
            return animation
        end

        local function Reset(object)
            local customAnimation = object:GetFirstAnimation()
            customAnimation.ctrl = nil
            customAnimation.parent = nil
            customAnimation.initialValue = nil
            customAnimation.endValue = nil
        end

        g_animationPool = ZO_ObjectPool:New(Factory, Reset)
    end

    local animation, key = g_animationPool:AcquireObject()
    animation.key = key
    return animation
end

local function LeadshineSmoothTransition(self, parent, value, maxWidth, forceInit, onStopCallback, customApproachAmountMs)
    local oldValue = self._oldVal or value
    local oldMax = self.maxWidth or maxWidth
    self._oldVal = value
    self.maxWidth = maxWidth
    self.onStopCallback = onStopCallback

    -- Early return when initialization is forced or maxWidth <= 0
    if forceInit or maxWidth <= 0 then
        self:ClearAnchors()
        self:SetAnchor(CENTER, parent, LEFT, value, 0)

        if self.animation then
            self.animation:Stop()
        end

        if onStopCallback then
            onStopCallback(self)
        end
        return
    end

    -- Adjust old value based on maxWidth change
    if oldMax > 0 and oldMax ~= maxWidth then
        local maxChange = maxWidth / oldMax
        oldValue = oldValue * maxChange
        self:ClearAnchors()
        self:SetAnchor(CENTER, parent, LEFT, oldValue, 0)
    end

    -- Acquire animation if not already available
    if not self.animation then
        self.animation = AcquireAnimation()
    end

    local customAnimation = self.animation:GetFirstAnimation()
    customAnimation:SetDuration(customApproachAmountMs or DEFAULT_ANIMATION_TIME_MS)
    customAnimation.ctrl = self
    customAnimation.parent = parent
    customAnimation.initialValue = oldValue
    customAnimation.endValue = value

    self.animation:PlayFromStart()
end

function StackedBar:UpdateLeadshine(value, percentPos)
    local leadshine = self.leadshine
    if not (leadshine and self.primary) then
        return
    end
    local temphide = self.uavInvuln and true or false
    local dead = value == 0
    leadshine:SetHidden(dead or temphide)
    LeadshineSmoothTransition(leadshine, self.bar, percentPos * self.barWidth, self.barWidth, false)
end

function StackedBar:UpdateResourceLabel(value, mx, force)
    local rnf = self.resourceNumberFormat
    if rnf == RESOURCE_NUMBERS_SETTING_OFF then
        return
    end
    -- skip if unchanged
    if (not force) and (value == self._lastTextValue and mx == self._lastTextMax) then
        return
    end
    self._lastTextValue = value
    self._lastTextMax = mx

    local text
    if rnf == RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT then
        local number = SB.sv.primaryResourceAbbr and ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false) or ZO_CommaDelimitNumber(value)
        text = string.format("%s (%d%%)", number, Util.FormatPercent(value, mx))
    elseif rnf == RESOURCE_NUMBERS_SETTING_NUMBER_ONLY then
        local number = SB.sv.primaryResourceAbbr and ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false) or ZO_CommaDelimitNumber(value)
        text = number
    else
        text = Util.FormatPercent(value, mx) .. "%"
    end

    self.resourceNumbers:SetText(text)
end

function StackedBar:SetValue(value, force)
    if not value or value < 0 or value ~= value then return end
    if value == self._lastValue and not force then
        return
    end
    self._lastValue = value

    local bar = self.bar
    local stacks = self.stacks or 1
    local mx = self.powerMax or select(2, bar:GetMinMax())
    if not mx or mx <= 0 then return end
    local peelColors = self.peelColors
    
    if stacks == 1 then
        ZO_StatusBar_SetGradientColor(bar, peelColors[1])
        ZO_StatusBar_SmoothTransition(bar, value, mx, false)

        if not self._single then
            self.backlayer:SetHidden(true)
            self.stacksLabel:SetHidden(true)
            self._single = true
        end

        self:UpdateLeadshine(value, value / mx)
        self:UpdateResourceLabel(value, mx, force)
        return
    end

    local chunk = mx / stacks
    local remainder = value % chunk

    local percentPos
    if value > 0 and remainder < EPSILON then
        percentPos = 1
    else
        percentPos = remainder / chunk
    end

    ZO_StatusBar_SmoothTransition(bar, percentPos * mx, mx, false)

    local currentBar = zo_ceil(value * stacks / mx)

    local function GetColorIndex(currentBar, stacks)
        if stacks <= 1 then
            return 1
        end

        local normalized = (currentBar - 1) / (stacks - 1)
        local index = zo_floor(normalized * (PEEL_COLORS_COUNT - 1)) + 1

        return index
    end

    local colorIndex = GetColorIndex(currentBar, stacks)
    local nextColor = GetColorIndex(zo_min(currentBar - 1, stacks), stacks)

    ZO_StatusBar_SetGradientColor(bar, peelColors[colorIndex])

    local showStacks = currentBar > 1
    local showStackCount = SB.sv.showStackCount
    self.backlayer:SetHidden(not showStacks)
    self.stacksLabel:SetHidden(not (showStacks and showStackCount))
    if showStacks then
        if showStackCount then
            self.stacksLabel:SetText("x" .. currentBar)
        end
        ZO_StatusBar_SetGradientColor(self.backlayer, peelColors[nextColor])
    end

    self:UpdateLeadshine(value, percentPos)
    self:UpdateResourceLabel(value, mx, force)
end

function StackedBar:ResetVisual()
    self.overlay:ClearAnchors()
    self.overlay:SetAnchor(TOPLEFT, nil, nil, -3, -3)
    self.overlay:SetAnchor(BOTTOMRIGHT, nil, nil, 3, 3)
    self.overlay:SetTexture()
    self.overlay:SetBlendMode(TEX_BLEND_MODE_COLOR_DODGE)
    self.overlay:SetColor(0, 0, 0, 0)
    self.overlayScrollAnim:Stop()
    self.overlay:SetHidden(true)
    if self.primary then
        self.leadshine:SetHidden(false)
    end
end

function StackedBar:SetInvulnVisual(bool)
    local b = (bool == nil) and true or bool
    if b then
        self.overlay:SetHidden(not b)
        self.overlay:SetTexture("SlayerBars/media/barber.dds")
        self.overlay:SetBlendMode()
        self.overlay:SetColor(unpack(SB.sv.targetInvulnColor))
        self.overlay:ClearAnchors()
        self.overlay:SetAnchor(TOPLEFT, nil, nil, 0, 0)
        self.overlay:SetAnchor(BOTTOMRIGHT, nil, nil, 0, 0)
        self.overlayScrollAnim:PlayFromStart()
        if self.primary then
            self.leadshine:SetHidden(true)
        end
    else
        self:ResetVisual()
    end
end

function StackedBar:InitUnit(force, customName, customCurrent, customMax, customStacks)
    local tag = self.unitTag
    if (self._lastUnitName ~= self.unitName) or force then
        self.unitName = customName or Util.GetNameOrDefault(tag)
        self.nameLabel:SetText(self.unitName)
    end
    -- UpdateStacksEnemyType()
    local c, m, em = GetUnitPower(tag, POWERTYPE_HEALTH)
    local current = customCurrent or c
    local maxhp = customMax or m
    local stacks = 1

    if self.primary then
        if GetUnitType(tag) == 12 then -- target dummy
            stacks = 5
        else
            local difficulty = GetUnitDifficulty(tag)
            if difficulty and difficulty >= MONSTER_DIFFICULTY_DEADLY then
                stacks = (maxhp > 100000000) and 20 or 5
            end
        end
    end
    self:SetStacks(customStacks or stacks)
    self:SetMinMax(0, maxhp)
    self:SetValue(current, force)
end

--------------------------------------------------------------
-- Update Functions
--------------------------------------------------------------

function StackedBar:AlignNameplate()
    local padBottom = -2
    local parent = self.nameLabel:GetParent()
    self.nameLabel:ClearAnchors()
    local a = SB.sv.nameAlignment
    if a == 1 then -- Left
       self.nameLabel:SetAnchor(BOTTOMLEFT, parent, TOPLEFT, 0, padBottom)
    elseif a == 2 then -- center
       self.nameLabel:SetAnchor(BOTTOM, parent, TOP, 0, padBottom)
    else -- Right
       self.nameLabel:SetAnchor(BOTTOMRIGHT, parent, TOPRIGHT, 0, padBottom)
    end
    
    local rnCtrl = self.resourceNumbers
    local stksCtrl = self.stacksLabel
    local padSide = 10
    padBottom = 1
    if self.primary then
        a = SB.sv.primaryResourceAlign
        rnCtrl:ClearAnchors()
        if a == 1 then -- Left
           rnCtrl:SetAnchor(LEFT, parent, LEFT, padSide, padBottom)
        elseif a == 2 then -- center
           rnCtrl:SetAnchor(CENTER, parent, CENTER, 0, padBottom)
        else -- Right
           rnCtrl:SetAnchor(RIGHT, parent, RIGHT, -1 * padSide, padBottom)
        end

        a = SB.sv.stackCountAlign
        local oX = 7
        local oY = 1
        stksCtrl:ClearAnchors()
        if a == 1 then -- Left
           stksCtrl:SetAnchor(LEFT, parent, LEFT, oX, oY)
        else -- Right
           stksCtrl:SetAnchor(RIGHT, parent, RIGHT, -1 * oX, oY)
        end
    else
        a = SB.sv.addBossResourceAlign
        rnCtrl:ClearAnchors()
        if a == 1 then -- Left
           rnCtrl:SetAnchor(LEFT, parent, LEFT, padSide, padBottom)
        elseif a == 2 then -- center
           rnCtrl:SetAnchor(CENTER, parent, CENTER, 0, padBottom)
        else -- Right
           rnCtrl:SetAnchor(RIGHT, parent, RIGHT, -1 * padSide, padBottom)
        end
    end
end

function StackedBar:UpdateTexture()
    ApplyTemplateToControl(self.bgBackdrop, SB.sv.backdropStyle)
    self.bar:SetTexture(LuiMedia.StatusbarTextures[SB.sv.targetBarTex])
    self.backlayer:SetTexture(LuiMedia.StatusbarTextures[SB.sv.targetBacklayerTex])
end

function StackedBar:UpdateUnitId(unitId)
    if self.unitId ~= unitId then
        self.unitId = unitId
        self.nameLabel:SetText(string.format("[%d] %s", unitId, self.unitName))
    end
end

function StackedBar:OnUnitAttributeVisualAdded(_, unitTag, uav, statType, attributeType, powerType, value, maxValue, sequenceId)
    if uav == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
        self:SetInvulnVisual()
    end
    if uav == ATTRIBUTE_VISUAL_POWER_SHIELDING then
    end
end

function StackedBar:OnUnitAttributeVisualUpdated( _, unitTag, uav, statType, attributeType, powerType, oldVal, newVal, oldMaxVal, newMaxValue, sequenceId)
    if uav == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
        if newVal == 0 then
            self.uavInvuln = false
            self:ResetVisual()
        else
            self.uavInvuln = true
            self:SetInvulnVisual()
        end
    end
    if uav == ATTRIBUTE_VISUAL_POWER_SHIELDING then
    end
end

function StackedBar:OnUnitAttributeVisualRemoved(_, unitTag, uav, statType, attributeType, powerType, value, maxValue, sequenceId)
    if uav == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
        self:ResetVisual()
    end
    if uav == ATTRIBUTE_VISUAL_POWER_SHIELDING then
    end
end

function StackedBar:Show()
    --self:RegisterUnit(self.unitTag)
    self:UpdateTexture()
    self.control:SetHidden(false)
end

function StackedBar:Release()
    self.control:SetHidden(true)
end

--------------------------------------------------------------
-- Top Level UI
--------------------------------------------------------------

function SB.ResetPosition()
    local heightUnit = SlayerBar:GetHeight()
    local key = SlayerBar:GetName()
    local zx, zy = ZO_CompassFrame:GetCenter()
    SB.sv.positions[key] = {zx - SlayerBar:GetWidth() / 2, zy + heightUnit}

    key = SlayerBarsOtherBars:GetName()
    SB.sv.positions[key] = {zx - SlayerBarsOtherBars:GetWidth() / 2, zy + (heightUnit * 2)}
end

function SB.ApplyPrimaryStyle(stackedBar)
    stackedBar.primary = true
    stackedBar.control:SetParent(SlayerBar)
    local width = SB.sv.primaryBarWidth
    local defaultHeight = SB.sv.primaryBarHeight
    stackedBar.control:SetDimensions(width, defaultHeight)
    stackedBar.barWidth = width
    stackedBar:EnableLeadshine()

    stackedBar.shakeAnim = stackedBar.shakeAnim or ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsUIShake", stackedBar.control)
    local fo = stackedBar.overlay
    stackedBar.flashAnim = stackedBar.flashAnim or ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsHitIndicatorAnimation", fo)
    stackedBar.flashAnim:SetHandler(
        "OnPlay",
        function()
            fo:SetHidden(false)
        end
    )
    stackedBar.flashAnim:SetHandler(
        "OnStop",
        function()
            fo:SetHidden(true)
        end
    )
    stackedBar.flashAnim:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG)
    stackedBar.flashAnim:SetPlaybackLoopCount(1)
    stackedBar.flashAnim:GetAnimation(1):SetDuration(300)

    stackedBar.nameLabel:SetFont(Util.FormatFont(SB.sv.primaryNameFont))
    stackedBar.resourceNumbers:SetFont(Util.FormatFont(SB.sv.primaryResourceFont))
    stackedBar.stacksLabel:SetFont(Util.FormatFont(SB.sv.primaryResourceFont))
    stackedBar:SetResourceFormat(SB.sv.primaryResourceNumberFormat)
end

function SB.ApplyOtherStyle(stackedBar)
    stackedBar.primary = false
    stackedBar.control:SetParent(SlayerBarsOtherBars)
    stackedBar.control:SetHeight(SB.sv.addBossBarHeight)
    stackedBar:DisableLeadshine()
    stackedBar.stacksLabel:SetHidden(true)
    stackedBar:SetStacks(1)
    stackedBar.nameLabel:SetFont(Util.FormatFont(SB.sv.addBossNameFont))
    stackedBar.resourceNumbers:SetFont(Util.FormatFont(SB.sv.addBossResourceFont))
    stackedBar:SetResourceFormat(SB.sv.addBossResourceNumberFormat)
end

function SB.Unlock(unlock)
    local u = (unlock == nil) and true or unlock
    SB.is_unlocked = u
    if u then
        for k, v in pairs(SB.instantiatedBars) do
            v:Show()
        end
        SB.instantiatedBars["boss7"]:SetInvulnVisual()
        GAME_MENU_SCENE:AddFragment(SB.other_bars_frag)
        GAME_MENU_SCENE:AddFragment(SB.primary_bar_frag)
    else
        GAME_MENU_SCENE:RemoveFragment(SB.other_bars_frag)
        GAME_MENU_SCENE:RemoveFragment(SB.primary_bar_frag)
        SB.OnBossesChanged(_, true)
    end
    SlayerBar:SetMovable(u)
    SlayerBarsOtherBars:SetMovable(u)
    SB.primary_bar_frag.hiddenReasons:SetShownForReason("Unlocked", u)
    SB.other_bars_frag.hiddenReasons:SetShownForReason("Unlocked", u)
    SB.primary_bar_frag:Refresh()
    SB.other_bars_frag:Refresh()
end

SB.OtherBarsPool =
    ZO_ObjectPool:New(
    function(pool)
        local c = ZO_ObjectPool_CreateControl("SlayerBarStatusTemplate", pool, SlayerBarsOtherBars)
        return StackedBar:New(nil, c)
    end,
    function(object)
        object:Release()
    end
)

function SB.UpdateDisplayLayout()
    local primaryFontSize = SB.sv.primaryNameFont[2]
    local primaryPaddingTop = primaryFontSize * 1.5

    SB.ApplyPrimaryStyle(PRIMARY_BAR)
    local secondBar = SB.instantiatedBars["boss2"]
    if SB.enemyTracker.twinFight then
        SB.ApplyPrimaryStyle(secondBar)
        secondBar.control:ClearAnchors()
        secondBar.control:SetAnchor(TOP, PRIMARY_BAR.control, BOTTOM, 0, primaryPaddingTop)
    else
        SB.ApplyOtherStyle(secondBar)
        local minPadding = 2
        local addiWidth = SB.sv.addBossBarWidth
        local addiHeight = SB.sv.addBossBarHeight
        local halfW = addiWidth / 2
        local secondaryFontSize = SB.sv.addBossNameFont[2]
        local innerPadding = 5
        local rowHeight = addiHeight + zo_max(minPadding, (secondaryFontSize * 1.5))
        for i = 2, MAX_BOSSES do
            local tag = "boss" .. i
            local stkd = SB.instantiatedBars[tag]
            stkd.control:ClearAnchors()
            stkd.control:SetHeight(addiHeight)
            if SB.sv.addBossDisplayLayout == SB.Settings.ADD_BOSS_DISPLAY_COMPACT then
                local evenOdd = i % 2
                local offsetY = (zo_floor(i / 2) * rowHeight) - secondaryFontSize
                stkd.barWidth = halfW - innerPadding
                stkd.control:SetWidth(stkd.barWidth)
                stkd.control:SetAnchor(TOPLEFT, SlayerBarsOtherBars, TOPLEFT, evenOdd * (halfW + innerPadding), offsetY)
            else
                local offsetY = (i - 2) * rowHeight + secondaryFontSize
                stkd.barWidth = addiWidth
                stkd.control:SetWidth(addiWidth)
                stkd.control:SetAnchor(TOPLEFT, SlayerBarsOtherBars, TOPLEFT, 0, offsetY)
            end
        end
        local rows = SB.sv.addBossDisplayLayout == SB.Settings.ADD_BOSS_DISPLAY_COMPACT and 3 or 6
        SlayerBarsOtherBars:SetDimensions(addiWidth, rowHeight * rows)
    end
    -- local _, _, _, _, topLvlWidth, topLvlHeight = Util.GetBounds(SlayerBar)
    -- local count = SlayerBar:GetNumChildren()
    SlayerBar:SetDimensions(SB.sv.primaryBarWidth + 100, SB.sv.primaryBarHeight + primaryPaddingTop)
    Util.CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
    SB.primary_bar_frag:Refresh()
    SB.other_bars_frag:Refresh()
end

function SB.UpdateBars()
    for k, v in pairs(SB.instantiatedBars) do
        if v.primary then
            SB.ApplyPrimaryStyle(v)
        else
            SB.ApplyOtherStyle(v)
        end
        v:UpdateTexture()
        v:AlignNameplate()
    end
    local key = SlayerBar:GetName()
    local key2 = SlayerBarsOtherBars:GetName()

    if not (SB.sv.positions[key] and SB.sv.positions[key2]) then
        SB.ResetPosition()
    end
    
    SlayerBar:ClearAnchors()
    SlayerBar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SB.sv.positions[key][1], SB.sv.positions[key][2])

    SlayerBarsOtherBars:ClearAnchors()
    SlayerBarsOtherBars:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SB.sv.positions[key2][1], SB.sv.positions[key2][2])
    
    SB.UpdateDisplayLayout()
end

function SB.UpdateScope(inCombat)
    SlayerBarTracker:SetHidden(true)
    local currentRole = GetSelectedLFGRole()
    local isTank = currentRole == LFG_ROLE_TANK
    SlayerBarTrackerIconDemon:SetHidden(not isTank)
    SlayerBarTrackerIconDemonGlow:SetHidden(not isTank)
    SlayerBarTrackerDiamondIndicator:SetHidden(currentRole == LFG_ROLE_TANK)

    if inCombat then
        SB.Anim.DiamondPulse:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
        SB.Anim.DiamondPulse:PlayFromStart()
    else
        SB.Anim.DizzyStop()
        SB.Anim.DiamondPulse:Stop()
    end
end

--------------------------------------------------------------
-- EVENT STATES
--------------------------------------------------------------
local RETICLE_OVER = "reticleover"
local inHouse = false
local obVisualActive = false
local lastReticleUnit = ""
local REASON_CUSTOM_LAYOUT = "CustomLayout"
local REASON_NO_BOSSES = "NoBosses"

function SB.Anim.DizzyStart()
    SB.Anim.DiamondPulse:Stop()
    SB.Anim.DizzyZoomIn:PlayFromStart()
    SB.Anim.DizzyRotate:PlayFromStart()
    PRIMARY_BAR:ImpactShake()
end

function SB.Anim.DizzyContinue()
    SB.Anim.DiamondPulse:Stop()
    SB.Anim.DizzyZoomIn:PlayForward()
    SB.Anim.DizzyRotate:PlayForward()
end

function SB.Anim.DizzyStop()
    if obVisualActive then
        SB.Anim.DizzyZoomOut:PlayFromStart()
        SB.Anim.DizzyRotate:Stop()
        SB.Anim.DiamondPulse:PlayFromStart()
        obVisualActive = false
        Util.CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
    end
end

function SB.Anim.CrosshairAimStart()
    if SlayerBarCrosshair:IsHidden() or not SB.Anim.CrosshairRotate:IsPlaying() then
        SlayerBarCrosshair:SetHidden(false)
        SB.Anim.CrosshairRotate:PlayFromStart()
    end
end

function SB.Anim.CrosshairAimEnd()
    if not SlayerBarCrosshair:IsHidden() or SB.Anim.CrosshairRotate:IsPlaying() then
        SB.Anim.CrosshairRotate:Stop()
        SlayerBarCrosshair:SetHidden(true)
    end
end

function SB.OnMoveStop(control)
    SB.sv.positions = SB.sv.positions or {}
    SB.sv.positions[control:GetName()] = {control:GetLeft(), control:GetTop()}
    SB.UpdateBars()
end

function SB.OnUpdate()
    local ET = SB.enemyTracker
    local showIds = SB.sv.showUnitIds
    local primaryId = ET.bossMap[boss1] or (inHouse and ET.reticleUnitId)

    if showIds then
        if inHouse and primaryId then
            PRIMARY_BAR:UpdateUnitId(primaryId)
        else
            for tag, v in pairs(ET.bossHealth) do
                local uId = ET.bossMap[tag]
                if uId then
                    local stkd = SB.instantiatedBars[tag]
                    stkd:UpdateUnitId(uId)
                end
            end
        end
    end

    if not primaryId then
        SB.Anim.DizzyStop()
        return
    end

    local unitEffects = ET.byId[primaryId]
    local ob_buff_info = unitEffects and unitEffects[SB.OB_NAME]

    if not ob_buff_info then
        SB.Anim.DizzyStop()
    else
        if not obVisualActive then
            Util.CircularTexture(SlayerBarTrackerFrameCircleInner, "/esoui/art/icons/ability_debuff_offbalance.dds")
            obVisualActive = true
        end

        if ob_buff_info[1] == 0 then
            SB.Anim.DizzyStart()
            ob_buff_info[1] = 1
        else
            SB.Anim.DizzyContinue()
        end
    end

    do
        local targetName = GetUnitName(RETICLE_OVER)
        local currentUnit = string.format('%d|%s', ET.reticleUnitId or 0, targetName)
        if targetName == nil and ET.reticleUnitId == nil then
            SB.Anim.CrosshairAimEnd()
        elseif currentUnit ~= lastReticleUnit then
            local stkd = ET:GetBarBy(ET.reticleUnitId, targetName)
            if stkd then
                local parent = stkd.control
                SlayerBarCrosshair:SetParent(parent)
                SlayerBarCrosshair:ClearAnchors()
                SlayerBarCrosshair:SetAnchor(CENTER, parent, TOPLEFT, 0, 3)
                SB.Anim.CrosshairAimStart()
            end
        end
        lastReticleUnit = currentUnit
    end
end

local function IsCloneFight(strict)
    local ET = SB.enemyTracker

    local function allSameName()
        local ref
        for tag, v in pairs(ET.bossHealth) do
            if v then
                local comp = GetUnitName(tag)
                if not ref then ref = comp end
                if ref ~= comp then return false end
            end
        end
        ET.cloneName = ref
        return true
    end

    local function allSameMaxHp()
        local ref
        for _, v in pairs(ET.bossHealth) do
            ref = ref or v.maxhp
            if v.maxhp ~= ref then return false end
        end
        return true
    end
    

    local function InOsseinCageShaperMap()
        return (GetZoneId(GetUnitZoneIndex("player")) == 1548 and (GetMapTileTexture():match('Art/maps/dungeons/OssCage_Section1Map002_0.dds')))
    end

    if strict then
        return InOsseinCageShaperMap() and allSameMaxHp() and allSameName()
    else
        return allSameMaxHp() and ET.activeBossCount > 2
    end
end

local function CloneFightDetected(count)
    local bossHps = SB.enemyTracker.bossHealth
    local consolidatedMax = 0
    local currentConsolidated = 0
    for tag, v in pairs(bossHps) do
        consolidatedMax = consolidatedMax + v.maxhp
        currentConsolidated = currentConsolidated + v.hp
    end

    local function OnClonePowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
        if not bossHps then return end
        
        if (self._lastUnitName ~= self.unitName) then
            self.unitName = ET.cloneName or Util.GetNameOrDefault(unitTag)
            self.nameLabel:SetText(self.unitName)
        end

        local t = bossHps[unitTag]
        if not t then return end
        t.hp = powerValue
        local currentConsolidated = 0
        for tag, v in pairs(SB.enemyTracker.bossHealth) do
            currentConsolidated = currentConsolidated + (v.hp or 0)
        end
        PRIMARY_BAR:SetValue(currentConsolidated)
    end

    local function PrimaryRegisterBosses()
        PRIMARY_BAR:Unregister()
        local controlName = PRIMARY_BAR.control:GetName()
        local evN = PRIMARY_BAR.eventNamespace or "SB_" .. controlName
        PRIMARY_BAR.onPowerUpdateHandler =
            ZO_MostRecentPowerUpdateHandler:New(
            evN,
            function(...)
                OnClonePowerUpdate(...)
            end
        )
        PRIMARY_BAR.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
        PRIMARY_BAR.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    end

    PRIMARY_BAR:InitUnit(true, nil, currentConsolidated, consolidatedMax, count)
    PrimaryRegisterBosses()
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, true)
end

function SB.CleanupBosses(resetPrimary)
    local ET = SB.enemyTracker
    if resetPrimary then
        PRIMARY_BAR:RegisterUnit(boss1)
    end
    ET.bossHealth = {}
    ET.twinFight = false
    ET.cloneFight = false
    SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, true)
    SB.other_bars_frag:SetHiddenForReason(REASON_NO_BOSSES, true)
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, false)
    SB.primary_bar_frag:Refresh()
    SB.other_bars_frag:Refresh()
end

function SB.RegisterDummy()
    inHouse = true
    PRIMARY_BAR:RegisterUnit(RETICLE_OVER)
end

function SB.UnregisterDummy()
    inHouse = false
    SB.CleanupBosses(true)
end

function SB.UpdateReticleTarget(unitExists)
    if inHouse then 
        SB.enemyTracker.activeBossCount = unitExists and 1 or 0
        PRIMARY_BAR:InitUnit(true)
        PRIMARY_BAR:Show()
        SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, true)
        SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, not unitExists)
        SB.primary_bar_frag:Refresh()
        -- SB.other_bars_frag:Refresh()
    end
end

function SB.OnBossesChanged(eventid, force)
    local ET = SB.enemyTracker
    local count = 0

    for i = 1, MAX_BOSSES do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            count = count + 1
            local current, maxhp, effmax = GetUnitPower(tag, POWERTYPE_HEALTH)
            ET.bossHealth[tag] = { hp = current, maxhp = maxhp }
        else
            ET.bossHealth[tag] = nil
            SB.instantiatedBars[tag]:Release()
        end
    end

    local respawn = ET.activeBossCount ~= count
    ET.activeBossCount = count

    if count == 0 then
        CALLBACK_MANAGER:FireCallbacks("OnBossFightEnd", ET.twinFight, ET.cloneFight)
    end

    SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, false)
    PRIMARY_BAR:Show()
    
    ET.twinFight = count == 2 and (ET.bossHealth[boss1] and ET.bossHealth[boss1].maxhp or 0) == (ET.bossHealth["boss2"] and ET.bossHealth["boss2"].maxhp or -1)
    SB.other_bars_frag:SetHiddenForReason(REASON_NO_BOSSES, count < 2)
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, ET.twinFight)

    ET.cloneFight = IsCloneFight(true)
    if ET.cloneFight then
       CloneFightDetected(count)
    else
        for tag, vals in pairs(ET.bossHealth) do
            if DoesUnitExist(tag) then
                local stkd = SB.instantiatedBars[tag]
                stkd:InitUnit(force)
                stkd:Show()
            end
        end
    end

    if force then
        SB.UpdateDisplayLayout()
    end
end

function SB.OnCombatEvent(eventid, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    local IDs = SB.enemyTracker.byId
    if IDs[targetUnitId] and sourceType == COMBAT_UNIT_TYPE_PLAYER and (result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK_CRITICAL) then
        local unitTag = IDs[targetUnitId].unitTag
        -- d(string.format('%s [%d] %s', unitTag, targetUnitId, targetName))
        if unitTag then
            local stkd = SB.instantiatedBars[unitTag]
            if not stkd:LeadIsHidden() then stkd.leadHit() end
        end
    end
end

--------------------------------------------------------------
-- Init
--------------------------------------------------------------
function SB.Anim.Init()
    SB.Anim.OBShake = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsUIShake", SlayerBarMain)
    SB.Anim.DizzyRotate = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsDizzyRotate", SlayerBarTrackerIconDizzyStars)
    SB.Anim.DizzyZoomIn = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomIn", SlayerBarTrackerIconDizzyStars)
    SB.Anim.DizzyZoomOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarTrackerIconDizzyStars)

    SB.Anim.DiamondIndicatorZoomOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarTrackerDiamondIndicator)
    SB.Anim.DiamondPulse = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarTrackerDiamondIndicator)
    SB.Anim.DiamondPulse:GetAnimation(1):SetDuration(500)
    SB.Anim.DiamondPulse:GetAnimation(2):SetDuration(500)
    local t = SB.Anim.DiamondPulse:InsertAnimation(ANIMATION_CUSTOM, SlayerBarTrackerDiamondIndicator)
    t:SetDuration(500)
    SB.Anim.DiamondPulse:SetAnimationOffset(t, 500)
    
    SB.Anim.CrosshairRotate = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsCrosshairRotate", SlayerBarCrosshair)
end

function SB.InitBars()

    PRIMARY_BAR = StackedBar:New(boss1, SlayerBarMain)
    SB.ApplyPrimaryStyle(PRIMARY_BAR)

    PRIMARY_BAR:RegisterUnit(boss1)
    EVENT_MANAGER:RegisterForEvent(SB.name.."CombatEvent", EVENT_COMBAT_EVENT,
        function(...)
            SB.OnCombatEvent(...)
        end
    )

    SB.other_bars_frag = ZO_HUDFadeSceneFragment:New(SlayerBarsOtherBars)
    SB.primary_bar_frag = ZO_HUDFadeSceneFragment:New(SlayerBar)

    SB.primary_bar_frag:SetConditional(function () return SB.is_unlocked or SB.enemyTracker.activeBossCount > 0 end)
    SB.other_bars_frag:SetConditional(function () return SB.is_unlocked or
        (SB.enemyTracker.activeBossCount > 1 and not SB.other_bars_frag.hiddenReasons:IsHidden())
        end)
    HUD_SCENE:AddFragment(SB.primary_bar_frag)
    HUD_UI_SCENE:AddFragment(SB.primary_bar_frag)
    HUD_SCENE:AddFragment(SB.other_bars_frag)
    HUD_UI_SCENE:AddFragment(SB.other_bars_frag)

    SB.instantiatedBars[boss1] = PRIMARY_BAR

    for i = 2, MAX_BOSSES do
        local tag = "boss" .. i
        local stkd = StackedBar:New(tag, nil, SlayerBarsOtherBars)
        stkd:SetMinMax(0, 1)
        stkd:SetValue(1)
        stkd:RegisterUnit(tag)
        stkd:UpdateTexture()
        SB.ApplyOtherStyle(stkd)
        SB.instantiatedBars[tag] = stkd
    end

    CALLBACK_MANAGER:RegisterCallback("OnBossFightEnd", function(twinFight, cloneFight)
        SB.CleanupBosses(cloneFight)
    end)

    SB.UpdateBars()
end
