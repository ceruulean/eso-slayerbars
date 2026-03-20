SlayerBars = SlayerBars or {}
local SB = SlayerBars
SB.name = "SlayerBars"
SB.displayName = "Slayer Bars"
SB.version = 0.1
SB.is_unlocked = true


local fragment
local MAIN_BAR = nil
local ANIM = {
	OBShake = nil,
	DizzyRotate = nil
}

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

local OB_EFFECTS = {
	icon = "/esoui/art/icons/ability_debuff_offbalance.dds",
	ob_ids = {62988},
	ob_immun_ids = {134599}
}

local function FormatPercent(c, m)
	return zo_round((c / m) * 100)
end

local function TableContains(tab, val)
	for key, value in pairs(tab) do
		if value == val then
			return true -- Found the value
		end
	end
	return false -- Value not found
end

local function CircularTexture(ctrl, texture)
	local cx, cy = ctrl:GetCenter()
	cx, cy = ctrl:GetCenter()
	ctrl:SetCircularClip(cx, cy, 39)
	ctrl:SetTexture(texture)
end

local timerActive = false
function debounce(fn, delay)
	local lastArgs = nil
	return function(...)
		lastArgs = {...}
		if timerActive then
			return
		end
		timerActive = true
		fn(unpack(lastArgs))
		zo_callLater(
			function()
				timerActive = false
			end,
			delay
		)
	end
end

local StackedBar = ZO_Object:Subclass()

function StackedBar:New(...)
	local manager = ZO_Object.New(self)
	manager:Initialize(...)
	return manager
end

function StackedBar:Initialize(unitTag, existingControl)
	self.unitTag = unitTag
	self.control = existingControl or CreateControlFromVirtual("SB_Stacked" .. unitTag, SlayerBar, "SBtatusTemplate")
	self.leadshine = GetControl(self.control, "Leadshine")
	self.bar = GetControl(self.control, "Bar")
	self._barWidth = self.bar:GetWidth()
	self.resourceNumbers = GetControl(self.control, "ResourceNumbers")
	self.bgBackdrop = GetControl(self.control, "BgBackdrop")

	self.backlayer = GetControl(self.control, "Backlayer")
	self.barCountLabel = GetControl(self.control, "BarCountLabel")
	self.nameLabel = GetControl(self.control, "NameLabel")
	-- :SetDimensions(width, height)
	self:UpdateDifficulty()
	self.bar:SetTexture(LUIE_MEDIA_UNITFRAMES_TEXTURES_INNERSHADOWGLOSS_DDS)
	self.backlayer:SetTexture(LUIE_MEDIA_UNITFRAMES_TEXTURES_CILO_DDS)
	self.rightBracket = GetControl(self.control, "RightBracket")
	self.rightBracketGlow = GetControl(self.control, "RightBracketGlow")
	self.rightBracketUnderlay = GetControl(self.control, "RightBracketUnderlay")
	self.leadshineIdle = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsLeadingShineIdle", self.leadshine)
	-- SlayerBarNameLabel:SetFont("LuiMedia/media/fonts/Adventure/adventure.slug|22|thick-outline")

	local updateHandler =
		ZO_MostRecentPowerUpdateHandler:New(
		"SB",
		function(...)
			self:OnPowerUpdate(...)
		end
	)
	updateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
	updateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, self.unitTag)

	self.leadshineIdle:PlayFromStart()
	self:RegisterImpactfulHit()

	self:UpdateStyle()
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
			self:CombatOutgoing(_, ...)
		end
	)
	self.control:AddFilterForEvent(EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

function StackedBar:CombatOutgoing(
	result,
	isError,
	abilityName,
	abilityGraphic,
	abilityActionSlotType,
	sourceName,
	sourceType,
	targetName,
	targetType,
	hitValue,
	powerType,
	damageType,
	log,
	sourceUnitId,
	targetUnitId,
	abilityId,
	overflow)
	local test =
		debounce(
		function()
			self.leadshineHitAnim:PlayFromStart()
			-- SB.diamondIndicatorZoomOut:PlayFromStart()
		end,
		800
	)
	if result == ACTION_RESULT_CRITICAL_DAMAGE or ACTION_RESULT_DOT_TICK_CRITICAL then
		test()
	end
end

function StackedBar:UpdateDifficulty()
	local difficulty = GetUnitDifficulty(self.unitTag)
	if not difficulty or difficulty < MONSTER_DIFFICULTY_DEADLY then
		self.barCount = 1
	else
		local value, max = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
		if max > 100000000 then
			self.barCount = 10
		else
			self.barCount = 5
		end
	end
	self.bucketWidth = self.barCount / PEEL_COLORS_COUNT
end

function StackedBar:OnPowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	if unitTag ~= self.unitTag then
		return
	end
	if self._lastPowerMax ~= powerMax or self._lastUnitName ~= self.unitName then
		self._lastUnitName = self.unitName
		self.unitName = GetUnitName(unitTag)
		self.nameLabel:SetText(self.unitName)
		self.bar:SetMinMax(0, powerMax)
	end
	self:SetValue(powerValue)
end

function StackedBar:SetMinMax(mn, mx)
	self.bar:SetMinMax(mn, mx)
end

local g_animationPool
local DEFAULT_ANIMATION_TIME_MS = 500

local function OnAnimationTransitionUpdate(animation, progress)
	local ctrl = animation.ctrl
	local initialValue = animation.initialValue
	local endValue = animation.endValue
	local newBarValue = zo_lerp(initialValue, endValue, progress)
	ctrl:ClearAnchors()
	ctrl:SetAnchor(CENTER, animation.parent, LEFT, newBarValue, 0)
end

local function OnStopAnimation(animation, completedPlaying)
	local animationKey = animation.key
	local ctrl = animation:GetFirstAnimation().ctrl
	ctrl.animation = nil
	g_animationPool:ReleaseObject(animationKey)
	if ctrl.onStopCallback then
		ctrl.onStopCallback(ctrl, completedPlaying)
	end
end

local function AcquireAnimation()
	if not g_animationPool then
		local function Factory(objectPool)
			local animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_StatusBarGrowTemplate")
			animation:GetFirstAnimation():SetUpdateFunction(OnAnimationTransitionUpdate)
			animation:SetHandler("OnStop", function(...) OnStopAnimation(...)  end)
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

local function LeadshineSmoothTransition(self, parent, value, max, forceInit, onStopCallback, customApproachAmountMs)
	local oldValue = self._oldVal or value
	local oldMax = self.max or max
	self._oldVal = value
	self.max = max
	self.onStopCallback = onStopCallback

	if forceInit or max <= 0 then
		self:ClearAnchors()
		self:SetAnchor(CENTER, parent, LEFT, value, 0)
		if self.animation then
			self.animation:Stop()
		end

		if onStopCallback then
			onStopCallback(self)
		end
	else
		if oldMax > 0 and oldMax ~= max then
			local maxChange = max / oldMax
			oldValue = oldValue * maxChange
			self:ClearAnchors()
			self:SetAnchor(CENTER, parent, LEFT, oldValue, 0)
		end

		if not self.animation then
			local updateAnimation = AcquireAnimation()
			self.animation = updateAnimation
		end

		local customAnimation = self.animation:GetFirstAnimation()
		customAnimation:SetDuration(customApproachAmountMs or DEFAULT_ANIMATION_TIME_MS)
		customAnimation.ctrl = self
		customAnimation.parent = parent
		customAnimation.initialValue = oldValue
		customAnimation.endValue = value

		self.animation:PlayFromStart()
	end
end

function StackedBar:SetValue(value)
	local bar = self.bar
	local mn, mx = bar:GetMinMax()
	local barCount = self.barCount

	local chunk = mx / barCount
	local remainder = value % chunk

	local percentPos
	if remainder < 0.0001 and value > 0 then
		percentPos = 1
	else
		percentPos = remainder / chunk
	end

	ZO_StatusBar_SmoothTransition(bar, percentPos * mx, mx, false)
	-- bar:SetValue(percentPos * mx)

	local currentBar = zo_ceil(value / mx * barCount)

	local colorSelect = zo_floor(currentBar / self.bucketWidth)
	local nextColor = zo_floor((currentBar - 1) / self.bucketWidth)

	if barCount == 1 then
		colorSelect = 1
	elseif barCount < PEEL_COLORS_COUNT then
		colorSelect = colorSelect - 1
		nextColor = colorSelect - 1
	end

	ZO_StatusBar_SetGradientColor(bar, PEEL_COLORS[colorSelect])

	local showStacks = currentBar > 1
	self.backlayer:SetHidden(not showStacks)
	self.barCountLabel:SetHidden(not showStacks)

	if showStacks then
		self.barCountLabel:SetText("x" .. currentBar)
		ZO_StatusBar_SetGradientColor(self.backlayer, PEEL_COLORS[nextColor])
	end

	if value == 0 then
		self.leadshine:SetHidden(true)
	else
		self.leadshine:SetHidden(false)
		self.leadshine:ClearAnchors()
		
		local current = percentPos * self._barWidth
		-- local eased = ZO_EaseOutCubic(percentPos)
		-- local k = zo_lerp(self._prev or current, current, eased) --ZO_EaseOutCubic()
		-- d(k .. "/" .. self._barWidth)
		-- self._prev = current
		self.leadshine:ClearAnchors()
		LeadshineSmoothTransition(self.leadshine, bar, current, self._barWidth, false)
		-- self.leadshine:SetAnchor(CENTER, bar, LEFT, percentPos * self._barWidth, 0)
	end

	self.resourceNumbers:SetText(
		ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false) ..
			" (" .. FormatPercent(value, mx) .. "%)"
	)
end

function SB.ResetPosition()
	local key = SlayerBar:GetName()
	local zx, zy = ZO_CompassFrame:GetCenter()
	SB.sv.positions[key] = { zx - SlayerBar:GetWidth() / 2, zy - SlayerBar:GetHeight() / 2 }
	SB.UpdateMainBar()
end

function StackedBar:UpdateStyle()
	SlayerBar:SetDimensions(SB.sv.targetBarWidth, SB.sv.targetBarHeight)
	self.bgBackdrop:ClearAnchors()
	ApplyTemplateToControl(self.bgBackdrop, SB.sv.backdropStyle)
	self.control:SetDimensions(SB.sv.targetBarWidth, SB.sv.targetBarHeight)
	self._barWidth = self.bar:GetWidth()
end

function SB.UpdateMainBar()
	MAIN_BAR:UpdateStyle()
	local key = SlayerBar:GetName()
	SlayerBar:ClearAnchors()
	SlayerBar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SB.sv.positions[key][1], SB.sv.positions[key][2])
	CircularTexture(SlayerBarFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
end


function SB.OnReticleTargetChanged(_)
	if DoesUnitExist("reticleover") and GetUnitReaction("reticleover") <= UNIT_REACTION_NEUTRAL then
		MAIN_BAR._lastUnitName = MAIN_BAR.unitName
		MAIN_BAR.unitName = GetUnitName(unitTag)
		MAIN_BAR:UpdateDifficulty()
	end
end

function SB.OnPlayerZoneChange(_)
	local UpdateEventName = SB.name .. "Update"
	if (GetCurrentZoneHouseId() > 0) then
		EVENT_MANAGER:RegisterForUpdate(UpdateEventName, 100, SB.OnUpdate)
	else
		--EVENT_MANAGER:UnregisterForEvent(EVENT_RETICLE_TARGET_CHANGED)
		EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
	end
end

function SB.OnCombatState(_, inCombat)
	if inCombat then
	else
		--
	end
end

function SB.OnEffectChanged(_,changeType,effectSlot,effectName,unitTag,beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceUnitType)
	if TableContains(OB_EFFECTS.ob_ids, abilityId) then
		if changeType == EFFECT_RESULT_GAINED then
			SlayerBarIconDemonGlow:SetHidden(true)
			CircularTexture(SlayerBarFrameCircleInner, OB_EFFECTS.icon)
			ANIM.DizzyZoomIn:PlayFromStart()
			ANIM.DizzyRotate:PlayFromStart()
			ANIM.OBShake:PlayFromStart()
		else
			CircularTexture(SlayerBarFrameCircleInner, LUIE_MEDIA_UNITFRAMES_TEXTURES_MELLIDARKROUGH_DDS)
			SlayerBarIconDemonGlow:SetHidden(false)
			ANIM.DizzyZoomOut:PlayFromStart()
		end
	elseif TableContains(OB_EFFECTS.ob_immun_ids, abilityId) then
		if changeType == EFFECT_RESULT_GAINED then
			local dur = endTime - beginTime
			SlayerBarInkBgOffBalance:SetHidden(false)
			SlayerBarInkBgOffBalance:SetMinMax(0, dur)
			SlayerBarInkBgOffBalance:SetValue(dur)
		elseif changeType == EFFECT_RESULT_FADED then
			SlayerBarInkBgOffBalance:SetHidden(true)
		end
	end
end

function SB.OnUpdate()
	for i = 1, GetNumBuffs("reticleover") do
		-- GRAB THE BUFF NAME INSTEAD OF THE ID
		local buffName, _, timeEnding = GetUnitBuffInfo("reticleover", i)

		if buffName == "Off Balance Immunity" then
			SlayerBarInkBgOffBalance:SetValue(zo_max(timeEnding - GetGameTimeSeconds(), 0))
		end
	end
end

function SB.OnMoveStop(control)
	SB.sv.positions = SB.sv.positions or {}
	SB.sv.positions[control:GetName()] = { control:GetLeft(), control:GetTop() }
	SB.UpdateMainBar()
end

function SB.Unlock()
	SlayerBar:SetMovable(true)
	GAME_MENU_SCENE:AddFragment(fragment)
end

function SB.Lock()
	SlayerBar:SetMovable(false)
	GAME_MENU_SCENE:RemoveFragment(fragment)
end

local function OnLoaded(_, name)
	if name ~= SB.name then
		return
	end
	SB.InitSettingsMenu()
	MAIN_BAR = StackedBar:New("reticleover", SlayerBarMain)
	fragment = ZO_SimpleSceneFragment:New(SlayerBar)
	SB.UpdateMainBar()
	ANIM.OBShake = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsUIShake", SlayerBarInkBg)
	ANIM.DizzyRotate = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsDizzyRotate", SlayerBarIconDizzyStars)
	ANIM.DizzyZoomIn = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomIn", SlayerBarIconDizzyStars)
	ANIM.DizzyZoomOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsZoomOut", SlayerBarIconDizzyStars)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
	if SB.is_unlocked then GAME_MENU_SCENE:AddFragment(fragment) end
	EVENT_MANAGER:RegisterForEvent(SB.name, EVENT_PLAYER_COMBAT_STATE, SB.OnCombatState)
	EVENT_MANAGER:RegisterForEvent(SB.name, EVENT_EFFECT_CHANGED, SB.OnEffectChanged)
	EVENT_MANAGER:RegisterForEvent(SB.name, EVENT_RETICLE_TARGET_CHANGED, SB.OnReticleTargetChanged)
	-- EVENT_MANAGER:RegisterForEvent(OBT.name, EVENT_GROUP_MEMBER_ROLE_CHANGED, OBT.UpdateVisibility)
	EVENT_MANAGER:RegisterForEvent(SB.name, EVENT_PLAYER_ACTIVATED, SB.OnPlayerZoneChange)

	EVENT_MANAGER:UnregisterForEvent(EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(SB.name, EVENT_ADD_ON_LOADED, OnLoaded)
