local LMP = LibMediaProvider
SlayerBars = {
	name = "SlayerBars",
	displayName = "Slayer Bars",
	version = "0.1",
	is_unlocked = false,
	ability = {},
	Anim = {},
	instantiatedBars = {},
	STATE = {
		OOC_IDLE = 0,
		COMBAT_IDLE = 1,
		DIZZY = 2,
		TAUNTED = 3,
		TAUNT_SOON = 4,
		UNTAUNTED = 5,
	}
}
local SB = SlayerBars
SB.currentState = SB.STATE.OOC_IDLE
local primary_bar_frag

local PRIMARY_BAR = nil
local ANIM = {
	OBShake = nil,
	DizzyRotate = nil
}

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

local OB_NAME
local OB_IMMUNE_NAME
local function RegisterAbilities()
	-- from untaunted mod....
	local AbilityCopies = {
		-- Minor Vulnerability
		[81519] = {51434, 61782, 68359, 79715, 79717, 79720, 79723, 79726, 79843, 79844, 79845, 79846, 117025, 118613, 120030, 124803, 124804, 124806, 130155, 130168, 130173, 130809},
		-- Minor Lifesteal
		[80020] = {86304, 86305, 86307, 88565, 88575, 88606, 92653, 121634, 148043},
		-- Minor Fracture
		[64144] = {79090, 79091, 79309, 79311, 60416, 84358},
		-- Minor Breach
		[68588] = {38688, 61742, 83031, 84358, 108825, 120019, 126685, 146908},
		-- Off Balance
		[62988] = {62968, 39077, 130145, 130129, 130139, 45902, 25256, 34733, 34737, 23808, 20806, 34117, 125750, 131562, 45834, 137257, 137312, 120014},
		-- Off Balance Immunity
		[134599] = {},
		-- Major Breach
		[62787] = {28307, 33363, 34386, 36972, 36980, 40254, 48946, 53881, 61743, 62474, 62485, 62775, 78609, 85362, 91175, 91200, 100988, 108951, 111788, 117818, 118438, 120010},
		-- Major Vulnerability
		[122389] = {106754, 106755, 106758, 106760, 106762, 122177, 122397},
		-- Minor Magickasteal
		[39100] = {26220, 26809, 88401, 88402, 88576, 125316, 148044},
		-- Taunt
		[38541] = {38254},
	}

	SB.ability[62988] = GetAbilityName(62988)
    SB.ability[134599] = GetAbilityName(134599)
	OB_NAME = SB.ability[62988]
	OB_IMMUNE_NAME = SB.ability[134599]
end

local OB_EFFECTS = {
	icon = "/esoui/art/icons/ability_debuff_offbalance.dds",
	ob_ids = {62988},
	ob_immun_ids = {134599}
}

local currentReticleUnitId = nil
enemyEffects = {
    byId = {},     -- [unitId] = { effects... }
    bossMap = {},  -- ["boss1"] = unitId
}

local function FormatPercent(c, m)
	local percent = (c/m) * 100
	if percent < 10 then
		percent = ZO_CommaDelimitDecimalNumber(zo_roundToNearest(percent, .1))
		percent = ZO_FastFormatDecimalNumber(percent)
	else
		percent = zo_round(percent)
	end

	return percent
end

local function FormatFont(svTable)
	local p = LMP:Fetch(LMP.MediaType.FONT, svTable[1]) or LMP:GetDefault(LMP.MediaType.FONT)
	return string.format("%s|%s|%s", p, svTable[2], svTable[3])
end

local function TableContains(tab, val)
	for key, value in pairs(tab) do
		if value == val then
			return true -- Found the value
		end
	end
	return false -- Value not found
end

local function GetNameOrDefault(unitTag)
	local DEFAULT_UNITNAME = GetString(SI_OPTIONS_ENEMY_NPC_NAMEPLATE_GAMEPAD)
	local name = GetUnitName(unitTag)
	return (name and name ~= "") and name or DEFAULT_UNITNAME
end

local function CircularTexture(ctrl, texture)
	local cx, cy = ctrl:GetCenter()
	ctrl:SetCircularClip(cx, cy, 39)
	ctrl:SetTexture(texture)
end

function debounce(fn, delay)
	local timerActive = false
	local lastArgs = nil

	return function(...)
		lastArgs = {...}
		if timerActive then return end

		timerActive = true
		fn(unpack(lastArgs))

		zo_callLater(function()
			timerActive = false
		end, delay)
	end
end

local StackedBar = ZO_Object:Subclass()

function StackedBar:New(...)
	local manager = ZO_Object.New(self)
	manager:Initialize(...)
	return manager
end

function StackedBar:Initialize(unitTag, existingControl, parentControl)
	self.control = existingControl or CreateControlFromVirtual("SB_Stacked" .. unitTag, parentControl or SlayerBar, "SlayerBarStatusTemplate")
	local ctrl = self.control
	self.leadshine = ctrl:GetNamedChild("Leadshine")
	self.bar = ctrl:GetNamedChild("Bar")
	self.barWidth = self.bar:GetWidth()
	self.resourceNumbers = ctrl:GetNamedChild("ResourceNumbers")
	self.resourceNumberFormat = RESOURCE_NUMBERS_SETTING_OFF
	self.bgBackdrop = ctrl:GetNamedChild("BgBackdrop")

	self.backlayer = ctrl:GetNamedChild("Backlayer")
	self.stacksLabel = ctrl:GetNamedChild("StacksLabel")
	self.unitName = GetNameOrDefault(unitTag)
	self.nameLabel = ctrl:GetNamedChild("NameLabel")

	self.leadshineIdle = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsLeadingShineIdle", self.leadshine)
	-- SlayerBarNameLabel:SetFont("LuiMedia/media/fonts/Adventure/adventure.slug|22|thick-outline")
	self.barContainer = ctrl:GetNamedChild("BarContainer")
	self.shakeAnim = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsUIShake", ctrl)

	local fo = ctrl:GetNamedChild("FlashOverlay")
	self.overlay = fo
	self.flashAnim = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsHitIndicatorAnimation", fo)
    self.flashAnim:SetHandler('OnPlay', function()
        fo:SetHidden(false)
    end)
    self.flashAnim:SetHandler('OnStop', function()
        fo:SetHidden(true)
    end)
	self.flashAnim:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG)
	self.flashAnim:SetPlaybackLoopCount(1)
	self.flashAnim:GetAnimation(1):SetDuration(300)

	self.overlayScrollAnim = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsScroll", fo)
	-- self.overlayScrollAnim:GetAnimation(1):SetDuration(5000)
	
	self:RegisterUnit(unitTag)
	self:RegisterImpactfulHit()
	self.leadshineIdle:PlayFromStart()
	self:UpdateStyle()
end

function StackedBar:RegisterUnit(unitTag)
	self.unitTag = unitTag
	if unitTag ~= nil then
		self.onPowerUpdateHandler = ZO_MostRecentPowerUpdateHandler:New("SB"..unitTag, function(...) self:OnPowerUpdate(...) end)
		self.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
		self.onPowerUpdateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, unitTag)
	end
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(...) self:OnUnitAttributeVisualAdded(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(...) self:OnUnitAttributeVisualUpdated(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
    self.control:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(...) self:OnUnitAttributeVisualRemoved(...) end)
    self.control:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, self.unitTag)
end

function StackedBar:UnregisterUnit()
	if self.onPowerUpdateHandler == nil then return end
	--EVENT_MANAGER:UnregisterForEvent("SB"..self.unitTag, EVENT_POWER_UPDATE)
	self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
	self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
	self.control:UnregisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
end

function StackedBar:ImpactShake()
	self.shakeAnim:PlayFromStart()
	self.flashAnim:PlayFromStart()
end

function StackedBar:RegisterImpactfulHit()
	-- dummy event since there's no way to detect boss hit, would have to do combt event instead
	self.leadshineHitAnim =
		ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsHitIndicatorAnimation", self.leadshine)

	SB.diamondIndicatorZoomOut =
		ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarDiamondIndicator)

	-- self.control:RegisterForEvent(EVENT_IMPACTFUL_HIT, function(_, ...) self:OnImpactfulHit(...) end )
	-- Player -> Target
	self.control:RegisterForEvent(
		EVENT_COMBAT_EVENT,
		function(_, ...)
			self:OnCombatEvent(_, ...)
		end
	)
	-- self.control:AddFilterForEvent(EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end


function StackedBar:OnCombatEvent(result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
	-- if self.unitName == targetName then d("traget: "..targetName) end
	if sourceType == COMBAT_UNIT_TYPE_PLAYER and (result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK_CRITICAL) then
		PRIMARY_BAR.leadHit()
	end
	if result == ACTION_RESULT_DIED then
		if currentReticleUnitId == targetUnitId then
			d("ReticleTargetDied")
		else
			d("Died:"..tostring(targetUnitId))
		end
	end
end

function StackedBar:SetStacks(count)
	self.stacks = count
	self.bucketWidth = self.stacks / PEEL_COLORS_COUNT
end

function StackedBar:UpdateDifficulty()
	local stacks
	local current, maxhp, effmax = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
	if GetUnitType(self.unitTag) == 12 then -- target dummy
		stacks = 5
	else
		local difficulty = GetUnitDifficulty(self.unitTag)
		if difficulty and difficulty >= MONSTER_DIFFICULTY_DEADLY then

			stacks = (maxhp > 100000000) and 10 or 5
		else
			stacks = 1
		end
	end
	self:SetStacks(stacks)
	self:OnPowerUpdate(self.unitTag, _, POWERTYPE_HEALTH, current, maxhp, effmax)
end

function StackedBar:OnPowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	if unitTag ~= self.unitTag then
		return
	end
	if self._lastPowerMax ~= powerMax or self._lastUnitName ~= self.unitName then
		self._lastUnitName = self.unitName
		self.unitName = GetNameOrDefault(unitTag)
		self.nameLabel:SetText(self.unitName)
		self:SetMinMax(0, powerMax)
	end
	self.uavInfo = { GetAllUnitAttributeVisualizerEffectInfo(unitTag) }
	-- { uav, statType, attributeType, powerType, value, maxValue }
	if self.uavInfo[1] == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
		self.uavImmune = true
		self:SetImmuneVisual()
	else
		self.uavImmune = false
	end
	self:SetValue(powerValue)
end

function StackedBar:SetMinMax(mn, mx)
	self._lastPowerMax = mx
	self.powerMax = mx
	self.bar:SetMinMax(mn, mx)
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
	if not ctrl then return end
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
	if not leadshine then return end
	local temphide = self.uavImmune and true or false
	local dead = value == 0
	if dead or temphide then
		leadshine:SetHidden(true)
	else
		LeadshineSmoothTransition( leadshine, self.bar, percentPos * self.barWidth, self.barWidth, false)
	end
end

function StackedBar:UpdateResourceLabel(value, mx, force)
	local rnf = self.resourceNumberFormat
	if rnf == RESOURCE_NUMBERS_SETTING_OFF then return end

	-- skip if unchanged
	if (not force) and (value == self._lastTextValue and mx == self._lastTextMax) then return end
	self._lastTextValue = value
	self._lastTextMax = mx

	local text
	if rnf == RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT then
		text = string.format(
			"%s (%d%%)",
			ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false),
			FormatPercent(value, mx)
		)
	elseif rnf == RESOURCE_NUMBERS_SETTING_NUMBER_ONLY then
		text = ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false)
	else
		text = FormatPercent(value, mx) .. "%"
	end

	self.resourceNumbers:SetText(text)
end

function StackedBar:SetValue(value, force)
	if value == self._lastValue and not force then return end
	self._lastValue = value

	local bar = self.bar
	local stacks = self.stacks or 1
	local mx = self.powerMax or select(2, bar:GetMinMax())

	if stacks == 1 then
		ZO_StatusBar_SetGradientColor(bar, PEEL_COLORS[1])
		ZO_StatusBar_SmoothTransition(bar, value, mx, false)

		if not self._singleHidden then
			self.backlayer:SetHidden(true)
			self.stacksLabel:SetHidden(true)
			self._singleHidden = true
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

	if colorIndex ~= self._lastColorIndex then
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

function StackedBar:UpdateStyle()
	ApplyTemplateToControl(self.bgBackdrop, SB.sv.backdropStyle)
	self.bar:SetTexture(LuiMedia.StatusbarTextures[SB.sv.targetBarTex])
	self.backlayer:SetTexture(LuiMedia.StatusbarTextures[SB.sv.targetBacklayerTex])
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
end

function StackedBar:SetImmuneVisual(bool)
	local b = (bool == nil) and true or bool
	if b then
		self.overlay:SetHidden(not b)
		self.overlay:SetTexture("SlayerBars/media/barber.dds")
		self.overlay:SetTextureCoords(0, 0.87, 0, 1) 
		self.overlay:SetBlendMode()
		self.overlay:SetColor(ZO_ColorDef:New("55aabd"):UnpackRGBA())
		self.overlay:ClearAnchors()
		self.overlay:SetAnchor(TOPLEFT, nil, nil, 0, 0)
		self.overlay:SetAnchor(BOTTOMRIGHT, nil, nil, 0, 0)
		self.overlayScrollAnim:PlayFromStart()
		if self.leadshine then self.leadshine:SetHidden(true) end
	else
		self:ResetVisual()
	end
end

function StackedBar:OnUnitAttributeVisualAdded(_, unitTag, uav, statType, attributeType, powerType, value, maxValue, sequenceId)
	if uav == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
		self:SetImmuneVisual()
	end
	if uav == ATTRIBUTE_VISUAL_POWER_SHIELDING then
	end
end

function StackedBar:OnUnitAttributeVisualUpdated(_, unitTag, uav, statType, attributeType, powerType, oldVal, newVal, oldMaxVal, newMaxValue, sequenceId)
	if uav == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
		if newVal == 0 then
			self.uavImmune = false
			self:ResetVisual()
		else
			self.uavImmune = true
			self:SetImmuneVisual()
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
	self:UpdateStyle()
	self.control:SetHidden(false)
end

function StackedBar:Release()
	-- self:UnregisterUnit()
	self.control:SetHidden(true)
end

function SB.ResetPosition()
	local heightUnit = SlayerBar:GetHeight()
	local key = SlayerBar:GetName()
	local zx, zy = ZO_CompassFrame:GetCenter()
	SB.sv.positions[key] = { zx - SlayerBar:GetWidth() / 2, zy + heightUnit }

	key = SlayerBarsOtherBars:GetName()
	SB.sv.positions[key] = { zx - SlayerBarsOtherBars:GetWidth() / 2, zy + (heightUnit * 2) }
	SB.UpdateAllBars()
end

function SB.UpdateScope()
	local currentRole = GetSelectedLFGRole()
	local isTank = currentRole == LFG_ROLE_TANK
	SlayerBarIconDemon:SetHidden(not isTank)
	SlayerBarIconDemonGlow:SetHidden(not isTank)
	SlayerBarDiamondIndicator:SetHidden(currentRole == LFG_ROLE_TANK)
end

function SB.UpdateAllBars()
	SlayerBar:SetDimensions(SB.sv.primaryBarWidth + 100, SB.sv.primaryBarHeight + 30)
	PRIMARY_BAR.nameLabel:SetFont(FormatFont(SB.sv.primaryNameFont))
	PRIMARY_BAR:SetResourceFormat(SB.sv.primaryResourceNumberFormat)
	PRIMARY_BAR:UpdateStyle()
	for k, v in pairs(SB.instantiatedBars) do
		if k ~= "boss1" then
			v.nameLabel:SetFont(FormatFont(SB.sv.addBossNameFont))
			v:SetResourceFormat(SB.sv.addBossResourceNumberFormat)
			v:UpdateStyle()
		end
	end
	local key = SlayerBar:GetName()
	local key2 = SlayerBarsOtherBars:GetName()

	if not (SB.sv.positions[key] and SB.sv.positions[key2])  then
		SB.ResetPosition()
	end

	SlayerBar:ClearAnchors()
	SlayerBar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SB.sv.positions[key][1], SB.sv.positions[key][2])
	CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)

	SlayerBarsOtherBars:ClearAnchors()
	SlayerBarsOtherBars:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SB.sv.positions[key2][1], SB.sv.positions[key2][2])
end

function SB.OnRoleChanged(_, unitTag, newRole)
	SlayerBarIconDemon:SetHidden(newRole ~= LFG_ROLE_TANK)
	SlayerBarIconDemonGlow:SetHidden(newRole ~= LFG_ROLE_TANK)
	SlayerBarDiamondIndicator:SetHidden(newRole == LFG_ROLE_TANK)
end

function SB.OnReticleTargetChanged()
	if not DoesUnitExist("reticleover") then
        currentReticleUnitId = nil
    end
end

function SB.OnPlayerZoneChange(_)
	local UpdateEventName = SB.name .. "Update"
	if (GetCurrentZoneHouseId() > 0) then
		-- EVENT_MANAGER:RegisterForUpdate(UpdateEventName, 100, SB.OnUpdate)
	else
		--EVENT_MANAGER:UnregisterForEvent(EVENT_RETICLE_TARGET_CHANGED)
		-- EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
	end
	SB.OnBossesChanged()
end

local function TrackUnit(unitTag, unitId)
    if not unitId then return end
    enemyEffects.byId[unitId] = enemyEffects.byId[unitId] or {}
    
	if unitTag == "reticleover" then
        currentReticleUnitId = unitId
    end
    if string.find(unitTag, "^boss%d+") then
        enemyEffects.bossMap[unitTag] = unitId
        enemyEffects.byId[unitId].unitTag = unitTag
    end
end

local UpdateEventName = SB.name .. "Update"
function SB.OnCombatState(_, inCombat)
	if inCombat then
		SB.Anim.DiamondPulse:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
		SB.Anim.DiamondPulse:PlayFromStart()
		SB.UpdateScope()
		EVENT_MANAGER:RegisterForUpdate(UpdateEventName, 100, SB.OnUpdate)
	else
		SB.UpdateScope()
		SB.Anim.DiamondPulse:Stop()
		EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
	end
end

function SB.OnEffectChanged(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceUnitType)
	TrackUnit(unitTag, unitId)
	local currentTime = GetGameTimeSeconds()
	if effectName == OB_NAME then
		if changeType == EFFECT_RESULT_GAINED then
			enemyEffects.byId[unitId][effectName] = { 0, beginTime, endTime }
		elseif changeType == EFFECT_RESULT_FADED	 then
			enemyEffects.byId[unitId][effectName] = nil
		end
	elseif effectName == OB_IMMUNE_NAME then
		if changeType == EFFECT_RESULT_GAINED then
			enemyEffects.byId[unitId][effectName] = { 0, beginTime, endTime }

			local dur = endTime - beginTime
			local now = GetFrameTimeMilliseconds()
			local total = (endTime - beginTime) * 1000
			local remaining = endTime * 1000 - GetFrameTimeMilliseconds()
            -- SlayerBarTrackerFrameCircleCooldown:SetHidden(false)
			-- SlayerBarFrameCircleCooldown:SetVerticalCooldownLeadingEdgeHeight(12)
            -- SlayerBarFrameCircleCooldown:SetAlpha(1)
			-- SlayerBarFrameCircleCooldown:StartCooldown(remaining, total, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL, false)
			SlayerBarInkBgOffBalance:SetHidden(false)
			SlayerBarInkBgOffBalance:SetMinMax(0, dur)
			SlayerBarInkBgOffBalance:SetValue(dur)
		elseif changeType == EFFECT_RESULT_FADED then
			-- SlayerBarFrameCircleCooldown:ResetCooldown()
			enemyEffects.byId[unitId][effectName] = nil
			SlayerBarInkBgOffBalance:SetHidden(true)
		end
	end
end

local RETICLE_OVER = "reticleover"
local obVisualActive = false

function SB.OnUpdate()
	local unitId = enemyEffects.bossMap["boss1"]
	if not unitId then
		if obVisualActive then
			-- CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
			SB.Anim.DizzyZoomOut:PlayFromStart()
			SB.Anim.DizzyRotate:Stop()
			SB.Anim.DiamondPulse:PlayFromStart()
			obVisualActive = false
		end
		return
	end

	local unitEffects = enemyEffects.byId[unitId]
	local ob_buff_info = unitEffects and unitEffects[OB_NAME]

	if not ob_buff_info then
		if obVisualActive then
			-- CircularTexture(SlayerBarTrackerFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
			SB.Anim.DizzyZoomOut:PlayFromStart()
			SB.Anim.DizzyRotate:Stop()
			SB.Anim.DiamondPulse:PlayFromStart()
			obVisualActive = false
		end
		return
	end

	if not obVisualActive then
		CircularTexture(SlayerBarTrackerFrameCircleInner, "/esoui/art/icons/ability_debuff_offbalance.dds")
		obVisualActive = true
	end

	if ob_buff_info[1] == 0 then
		SB.Anim.DizzyZoomIn:PlayFromStart()
		SB.Anim.DizzyRotate:PlayFromStart()
		SB.Anim.DiamondPulse:Stop()
		PRIMARY_BAR:ImpactShake()
		ob_buff_info[1] = 1
	else
		SB.Anim.DizzyZoomIn:PlayForward()
		SB.Anim.DizzyRotate:PlayForward()
		SB.Anim.DiamondPulse:Stop()
	end
end

function SB.OnMoveStop(control)
	SB.sv.positions = SB.sv.positions or {}
	SB.sv.positions[control:GetName()] = { control:GetLeft(), control:GetTop() }
	SB.UpdateAllBars()
end

function SB.Unlock(unlock)
	local u = (unlock == nil) and true or unlock
	SlayerBar:SetMovable(u)
	SlayerBar:SetHidden(not u)
	SlayerBarsOtherBars:SetMovable(u)
	SlayerBarsOtherBars:SetHidden(not u)
	if u then
		for k,v in pairs(SB.instantiatedBars) do
			v:Show()
		end
		SB.instantiatedBars["boss7"]:SetImmuneVisual()
		GAME_MENU_SCENE:AddFragment(SB.other_bars_frag)
		GAME_MENU_SCENE:AddFragment(primary_bar_frag)
	else
		SB.OnBossesChanged(_, true)
		GAME_MENU_SCENE:RemoveFragment(SB.other_bars_frag)
		GAME_MENU_SCENE:RemoveFragment(primary_bar_frag)
	end
end

SB.pool = ZO_ObjectPool:New(function(pool)
		local c = ZO_ObjectPool_CreateControl("SlayerBarStatusTemplate", pool, SlayerBarsOtherBars)
		return StackedBar:New(nil, c)
	end, function(object)
		object:Release()
	end)

function SB.Anim.Init()
	SB.Anim.OBShake = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsUIShake", SlayerBarMain)
	
	SB.Anim.DizzyRotate = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsDizzyRotate", SlayerBarIconDizzyStars)
	SB.Anim.DizzyZoomIn = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomIn", SlayerBarIconDizzyStars)
	SB.Anim.DizzyZoomOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarIconDizzyStars)
	
	SB.Anim.DiamondPulse = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarDiamondIndicator)
	SB.Anim.DiamondPulse:GetAnimation(1):SetDuration(500)
	SB.Anim.DiamondPulse:GetAnimation(2):SetDuration(500)
	local t = SB.Anim.DiamondPulse:InsertAnimation(ANIMATION_CUSTOM, SlayerBarDiamondIndicator)
	t:SetDuration(500)
	SB.Anim.DiamondPulse:SetAnimationOffset(t,500)
end

function SB.ToDizzy()
end

function SB.OnBossesChanged(_, forceReset)
	local count = 0
	local primary = "boss1"
	if DoesUnitExist(primary) then
		SlayerBar:SetHidden(false)
		count = 1
		PRIMARY_BAR:UpdateDifficulty()
		PRIMARY_BAR:Show()
		SlayerBarTracker:SetHidden(false)
	else
		SlayerBar:SetHidden(true)
		SlayerBarTracker:SetHidden(true)
		PRIMARY_BAR:Release()
	end
	for i = 2, MAX_BOSSES do
		local tag = "boss"..i
		if DoesUnitExist(tag) then
			count = count + 1
			local stkd = SB.instantiatedBars[tag]
			local current, maxhp, effmax = GetUnitPower(tag, POWERTYPE_HEALTH)
			stkd:OnPowerUpdate(tag, _, POWERTYPE_HEALTH, current, maxhp, effmax)
			stkd:Show()
		else
			SB.instantiatedBars[tag]:Release()
		end
	end

	SlayerBarsOtherBars:SetHidden(not (count > 1))
	SB.activeBossCount = count
end


function SB.UpdateDisplayLayoutOld()
	local minPadding = 2
	local width = SB.sv.primaryBarWidth
	local defaultHeight = SB.sv.primaryBarHeight
	PRIMARY_BAR.control:SetDimensions(width, defaultHeight)
	PRIMARY_BAR.barWidth = width
	local addiWidth = SB.sv.addBossBarWidth
	local addiHeight = SB.sv.addBossBarHeight
	local halfW = addiWidth / 2
	local secondaryFontSize = SB.sv.addBossNameFont[2]
	local innerPadding = 5
	local rowHeight = addiHeight + zo_max(minPadding, (secondaryFontSize * 1.5))
	for i = 2, MAX_BOSSES do
		local tag = "boss"..i
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

function SB.UpdateDisplayLayout()
	local minPadding = 2
	local width = SB.sv.primaryBarWidth
	local defaultHeight = SB.sv.primaryBarHeight

	PRIMARY_BAR.control:SetDimensions(width, defaultHeight)
	PRIMARY_BAR.barWidth = width

	local addiWidth = SB.sv.addBossBarWidth
	local addiHeight = SB.sv.addBossBarHeight
	local halfW = addiWidth / 2
	local secondaryFontSize = SB.sv.addBossNameFont[2]
	local innerPadding = 5
	local rowHeight = addiHeight + zo_max(minPadding, (secondaryFontSize * 1.5))

	local lastControl = nil
	local lastRowFirstControl = nil
	local isCompact = SB.sv.addBossDisplayLayout == SB.Settings.ADD_BOSS_DISPLAY_COMPACT

	for i = 2, MAX_BOSSES do
		local tag = "boss"..i
		local stkd = SB.instantiatedBars[tag]
		local ctrl = stkd.control

		ctrl:ClearAnchors()
		ctrl:SetHeight(addiHeight)

		if isCompact then
			-- normalize index so boss2 = 1
			local idx = i - 1
			local isEven = (idx % 2 == 0) -- even = right column

			stkd.barWidth = halfW - innerPadding
			ctrl:SetWidth(stkd.barWidth)

			if idx == 1 then
				-- first element
				ctrl:SetAnchor(TOPLEFT, SlayerBarsOtherBars, TOPLEFT, 0, secondaryFontSize)
				lastRowFirstControl = ctrl

			elseif isEven then
				-- right column → anchor to left sibling
				ctrl:SetAnchor(TOPLEFT, lastControl, TOPRIGHT, innerPadding * 2, 0)

			else
				-- new row → anchor below previous row FIRST element
				ctrl:SetAnchor(TOPLEFT, lastRowFirstControl, BOTTOMLEFT, 0, rowHeight - addiHeight)
				lastRowFirstControl = ctrl
			end

			lastControl = ctrl

		else 			-- vertical layout
			stkd.barWidth = addiWidth
			ctrl:SetWidth(addiWidth)

			if not lastControl then
				ctrl:SetAnchor(TOPLEFT, SlayerBarsOtherBars, TOPLEFT, 0, secondaryFontSize)
			else
				ctrl:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, rowHeight - addiHeight)
			end

			lastControl = ctrl
		end
	end

	local rows = isCompact and 3 or 6
	SlayerBarsOtherBars:SetDimensions(SB.sv.primaryBarWidth, rowHeight * rows)
end

function SB.InitBars()
	PRIMARY_BAR = StackedBar:New("boss1", SlayerBarMain)
	PRIMARY_BAR.leadHit = debounce(function()
		self.leadshineHitAnim:PlayFromStart()
	end, 800)
	SB.other_bars_frag = ZO_SimpleSceneFragment:New(SlayerBarsOtherBars)
	primary_bar_frag = ZO_SimpleSceneFragment:New(SlayerBar)
	HUD_SCENE:AddFragment(primary_bar_frag)
	HUD_UI_SCENE:AddFragment(primary_bar_frag)
	SB.instantiatedBars["boss1"] = PRIMARY_BAR
	for i = 2, MAX_BOSSES do
		local tag = "boss"..i
		local stkd = StackedBar:New(tag, nil, SlayerBarsOtherBars)
		stkd:SetStacks(1)
		stkd:SetMinMax(0,1)
		stkd:SetValue(1)
		stkd:UpdateStyle()
		stkd.leadshine:SetHidden(true)
		stkd.leadshine = nil -- do not update or show
		SB.instantiatedBars[tag] = stkd
	end
	SB.UpdateDisplayLayout()
	SB.UpdateAllBars()
	HUD_SCENE:AddFragment(SB.other_bars_frag)
	HUD_UI_SCENE:AddFragment(SB.other_bars_frag)
end

local function OnLoaded(_, name)
	if name ~= SB.name then return end
    SB.is_console = IsConsoleUI()
	RegisterAbilities()
	SB.InitSettingsMenu()
	SB.InitBars()
	SB.Anim.Init()
	SB.UpdateScope()
	SB.Unlock(SB.is_unlocked)
	COMPASS_FRAME:SetBossBarHiddenForReason(SB.name, true)
	EVENT_MANAGER:RegisterForEvent(SB.name.."CombatState", EVENT_PLAYER_COMBAT_STATE, SB.OnCombatState)
	EVENT_MANAGER:RegisterForEvent(SB.name.."EffectChange", EVENT_EFFECT_CHANGED, SB.OnEffectChanged)
	EVENT_MANAGER:RegisterForEvent(SB.name.."ReticleTarget", EVENT_RETICLE_TARGET_CHANGED, SB.OnReticleTargetChanged)
	-- EVENT_MANAGER:RegisterForEvent(SB.name.."RoleSwap", EVENT_GROUP_MEMBER_ROLE_CHANGED, SB.OnRoleChanged)
	-- EVENT_MANAGER:AddFilterForEvent(SB.name.."RoleSwap", EVENT_GROUP_MEMBER_ROLE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
	EVENT_MANAGER:RegisterForEvent(SB.name.."PlayerLoaded", EVENT_PLAYER_ACTIVATED, SB.OnPlayerZoneChange)
    -- EVENT_MANAGER:RegisterForEvent(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() RefreshAllBosses(true) end)
    EVENT_MANAGER:RegisterForEvent(SB.name.."BossesChanged", EVENT_BOSSES_CHANGED, SB.OnBossesChanged)
	EVENT_MANAGER:UnregisterForEvent(EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(SB.name.."AddonLoad", EVENT_ADD_ON_LOADED, OnLoaded)
