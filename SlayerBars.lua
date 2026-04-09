SlayerBars = SlayerBars or {}
local SB = SlayerBars
local LMP = LibMediaProvider

SB.is_unlocked = false
SB.Anim = {}
SB.instantiatedBars = {}
-- Modules --
SlayerBars.Util = {}
local Util = SlayerBars.Util

SB.primary_bar_frag = nil
SB.other_bars_frag = nil
local boss1 = "boss1"
local PRIMARY_BAR = nil

local EPSILON = 0.0001
local PEEL_COLORS_COUNT = 10
local PEEL_COLORS = {
    ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH],
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
    -- self.overlayScrollAnim:GetAnimation(1):SetDuration(5000)
end

function StackedBar:RegisterUnit(unitTag)
    self.unitTag = unitTag
    local controlName = self.control:GetName()
    if unitTag ~= nil then
        self.onPowerUpdateHandler =
            ZO_MostRecentPowerUpdateHandler:New(
            "SB" .. controlName,
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
    if self.onPowerUpdateHandler == nil then
        return
    end
    local namespace = self.onPowerUpdateHandler.namespace
    EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_POWER_UPDATE)
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
    self.bucketWidth = self.stacks / PEEL_COLORS_COUNT
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
    if not (leadshine or self.primary) then
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
        text =
            string.format(
            "%s (%d%%)",
            ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false),
            Util.FormatPercent(value, mx)
        )
    elseif rnf == RESOURCE_NUMBERS_SETTING_NUMBER_ONLY then
        text = ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false)
    else
        text = Util.FormatPercent(value, mx) .. "%"
    end

    self.resourceNumbers:SetText(text)
end

function StackedBar:SetValue(value, force)
    if value == self._lastValue and not force then
        return
    end
    self._lastValue = value

    local bar = self.bar
    local stacks = self.stacks or 1
    local mx = self.powerMax or select(2, bar:GetMinMax())

    if stacks == 1 then
        ZO_StatusBar_SetGradientColor(bar, PEEL_COLORS[1])
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
    local bucketWidth = self.bucketWidth

    local colorIndex = zo_floor(currentBar / bucketWidth)
    local nextColor = zo_floor((currentBar - 1) / bucketWidth)

    if stacks < PEEL_COLORS_COUNT then
        colorIndex = colorIndex - 1
        nextColor = nextColor - 1
    end

    if (colorIndex ~= self._lastColorIndex) or force then
        self._lastColorIndex = colorIndex
        ZO_StatusBar_SetGradientColor(bar, PEEL_COLORS[colorIndex])
    end

    local showStacks = currentBar > 1
    self.backlayer:SetHidden(not showStacks)
    self.stacksLabel:SetHidden(not showStacks)
    if showStacks then
        self.stacksLabel:SetText("x" .. currentBar)
        ZO_StatusBar_SetGradientColor(self.backlayer, PEEL_COLORS[nextColor])
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

function StackedBar:SetUnitInfo(force)
    local tag = self.unitTag
    local current, maxhp, effmax = GetUnitPower(tag, POWERTYPE_HEALTH)
    if (self._lastUnitName ~= self.unitName) or force then
        self.unitName = Util.GetNameOrDefault(tag)
        self.nameLabel:SetText(self.unitName)
    end
    SB.enemyTracker.bossHealth[tag] = { hp = current, maxhp = maxhp }
    -- UpdateStacksEnemyType()
    local stacks = 1
    if self.primary then
        if GetUnitType(tag) == 12 then -- target dummy
            stacks = 5
        else
            local difficulty = GetUnitDifficulty(tag)
            if difficulty and difficulty >= MONSTER_DIFFICULTY_DEADLY then
                stacks = (maxhp > 100000000) and 10 or 5
            end
        end
    end
    self:SetStacks(stacks)
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
    if a == 1 then -- Right
       self.nameLabel:SetAnchor(BOTTOMLEFT, parent, TOPLEFT, 0, padBottom)
    elseif a == 2 then -- center
       self.nameLabel:SetAnchor(BOTTOM, parent, TOP, 0, padBottom)
    else -- Left
       self.nameLabel:SetAnchor(BOTTOMRIGHT, parent, TOPRIGHT, 0, padBottom)
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
    SB.UpdateBars()
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
    stackedBar:SetResourceFormat(SB.sv.primaryResourceNumberFormat)
end

function SB.ApplyOtherStyle(stackedBar)
    stackedBar.primary = false
    stackedBar.control:SetParent(SlayerBarsOtherBars)
    stackedBar.control:SetHeight(SB.sv.addBossBarHeight)
    stackedBar:DisableLeadshine()
    stackedBar:SetStacks(1)
    stackedBar.nameLabel:SetFont(Util.FormatFont(SB.sv.addBossNameFont))
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
        secondBar:SetUnitInfo()
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
        SlayerBarsOtherBars:SetDimensions(SB.sv.primaryBarWidth, rowHeight * rows)
    end
    -- local _, _, _, _, topLvlWidth, topLvlHeight = Util.GetBounds(SlayerBar)
    -- local count = SlayerBar:GetNumChildren()
    SlayerBar:SetDimensions(SB.sv.primaryBarWidth + 100, SB.sv.primaryBarHeight + primaryPaddingTop)
    Util.CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
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

--------------------------------------------------------------
-- EVENT STATES
--------------------------------------------------------------
local RETICLE_OVER = "reticleover"
local inHouse = false
local obVisualActive = false
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

function SB.OnMoveStop(control)
    SB.sv.positions = SB.sv.positions or {}
    SB.sv.positions[control:GetName()] = {control:GetLeft(), control:GetTop()}
    SB.UpdateBars()
end

function SB.OnCombatState(_, inCombat)
-- "/esoui/art/armory/builditem_icon.dds"
-- "/esoui/art/worldmap/map_centerreticle.dds"
-- "/esoui/art/reticle/reticleanim-circle.dds"
    local UpdateEventName = SB.name .. "Update"
    if inCombat then
        SB.Anim.DiamondPulse:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
        SB.Anim.DiamondPulse:PlayFromStart()
        SB.UpdateScope()
        EVENT_MANAGER:RegisterForUpdate(UpdateEventName, 100, SB.OnUpdate)
    else
        SB.UpdateScope()
        SB.Anim.DizzyStop()
        SB.Anim.DiamondPulse:Stop()
        EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
    end
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
        return
    end

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

local function CloneFightDetected(count)
    local bossHps = SB.enemyTracker.bossHealth
    local consolidatedMax = 0
    for k, v in pairs(bossHps) do
        consolidatedMax = consolidatedMax + v.maxhp
    end

    local function OnClonePowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
        local t = SB.enemyTracker.bossHealth[unitTag]
        if not t then return end
        t.hp = powerValue
        if PRIMARY_BAR._lastPowerMax ~= consolidatedMax then
            PRIMARY_BAR:SetMinMax(0, consolidatedMax)
        end
        -- PRIMARY_BAR.uavInfo = {GetAllUnitAttributeVisualizerEffectInfo(unitTag)}
        -- -- { uav, statType, attributeType, powerType, value, maxValue }
        -- if PRIMARY_BAR.uavInfo[1] == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
            -- PRIMARY_BAR.uavInvuln = true
            -- PRIMARY_BAR:SetInvulnVisual()
        -- else
            -- PRIMARY_BAR.uavInvuln = false
        -- end
        local currentConsolidated = 0
        for k, v in pairs(bossHps) do
            currentConsolidated = currentConsolidated + v.hp
        end
        PRIMARY_BAR:SetValue(currentConsolidated)
    end

    local function PrimaryRegisterBosses()
        PRIMARY_BAR:Unregister()
        local controlName = PRIMARY_BAR.control:GetName()
        PRIMARY_BAR.onPowerUpdateHandler =
            ZO_MostRecentPowerUpdateHandler:New(
            "SB" .. controlName,
            function(...)
                OnClonePowerUpdate(...)
            end
        )
        PRIMARY_BAR.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
        PRIMARY_BAR.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    end

    PRIMARY_BAR:SetStacks(count)
    PrimaryRegisterBosses()
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, true)
end

function SB.CleanupBosses(resetPrimary)
    if resetPrimary then
        PRIMARY_BAR:Unregister()
        PRIMARY_BAR:RegisterUnit(boss1)
    end
    SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, true)
    SB.other_bars_frag:SetHiddenForReason(REASON_NO_BOSSES, true)
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, false)
end

function SB.RegisterDummy()
    inHouse = true
    PRIMARY_BAR:Unregister()
    PRIMARY_BAR:RegisterUnit(RETICLE_OVER)
end

function SB.UnregisterDummy()
    inHouse = false
    SB.CleanupBosses(true)
end

function SB.UpdateReticleTarget(unitExists)
    if not inHouse then return end
    SB.activeBossCount = unitExists and 1 or 0
    if unitExists then
       PRIMARY_BAR:SetUnitInfo(true)
       PRIMARY_BAR:Show()
    end
    SB.other_bars_frag:SetHiddenForReason(REASON_CUSTOM_LAYOUT, true)
    SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, not unitExists)
    SB.primary_bar_frag:Refresh()
    -- SB.other_bars_frag:Refresh()
end

function SB.OnBossesChanged(eventid, force)
    local ET = SB.enemyTracker
    local count = 0
    for i = 1, MAX_BOSSES do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            count = count + 1
            local stkd = SB.instantiatedBars[tag]
            if i == 1 then
                SB.primary_bar_frag:SetHiddenForReason(REASON_NO_BOSSES, false)
            end
            stkd:SetUnitInfo(force)
            stkd:Show()
        elseif not SB.is_unlocked then
            SB.instantiatedBars[tag]:Release()
        end
    end
    SB.activeBossCount = count
    if count == 0 then
        CALLBACK_MANAGER:FireCallbacks("OnBossFightEnd", ET.twinFight, ET.cloneFight)
        ET.bossHealth = {}
        ET.twinFight = false
        ET.cloneFight = false
    else
        ET.twinFight = count == 2 and ET.bossHealth[boss1].maxhp == ET.bossHealth["boss2"].maxhp
        local consolidatedMax = 0

        local function allSameMaxHp()
            local ref
            for _, v in pairs(ET.bossHealth) do
                ref = ref or v.maxhp
                if v.maxhp ~= ref then return false end
            end
            return true
        end
        ET.cloneFight = allSameMaxHp() and count > 2
        
        if ET.cloneFight then
           CloneFightDetected(count)
        end
        SB.other_bars_frag:SetHiddenForReason(REASON_NO_BOSSES, false)
        -- SB.other_bars_frag:SetHiddenForReason("CustomLayout", SB.enemyTracker.twinFight or SB.enemyTracker.cloneFight)
    end
    SB.UpdateDisplayLayout()
    SB.primary_bar_frag:Refresh()
    SB.other_bars_frag:Refresh()
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

    SB.primary_bar_frag:SetConditional(function () return SB.is_unlocked or SB.activeBossCount > 0 end)
    SB.other_bars_frag:SetConditional(function () return SB.is_unlocked or
        (SB.activeBossCount > 1 and not SB.other_bars_frag.hiddenReasons:IsHidden())
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
