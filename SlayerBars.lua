SlayerBars = {
	name = "SlayerBars",
	displayName = "Slayer Bars",
}

local MAIN_BAR = SlayerBarMain

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
	icon = '/esoui/art/icons/ability_debuff_offbalance.dds',
	ob_ids = { 62988 },
	ob_immun_ids = { 134599 }
}

local function FormatPercent(c, m)
	return zo_round((c / m) * 100)
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
        zo_callLater(function()
            timerActive = false
        end, delay)
    end
end

local lockUI = false

local StackedBar = ZO_Object:Subclass()

function StackedBar:New(...)
    local manager = ZO_Object.New(self)
    manager:Initialize(...)
    return manager
end

function StackedBar:Initialize(unitTag, existingControl)
	self.unitTag = unitTag
	self.control = existingControl or CreateControlFromVirtual("SlayerBar"..unitTag, SlayerBar, "SlayerBarStatusTemplate")
	self.leadshine = GetControl(self.control, "Leadshine")
	self.bar = GetControl(self.control, "Bar")
	self.resourceNumbers = GetControl(self.control, "ResourceNumbers")

	self.backlayer = GetControl(self.control, "Backlayer")
	self.bucketNumber = GetControl(self.control, "BucketNumber")
	self.nameLabel = GetControl(self.control, "NameLabel")
	-- :SetDimensions(width, height)
	self.barCount = 5
	
	self.bar:SetTexture("LuiMedia/media/unitframes/textures/InnerShadowGloss.dds")
	self.backlayer:SetTexture("LuiMedia/media/unitframes/textures/Cilo.dds")
	
	self.leadshineIdle = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsLeadingShineIdle", self.leadshine)
	-- SlayerBarNameLabel:SetFont("LuiMedia/media/fonts/Adventure/adventure.slug|22|thick-outline")

	local updateHandler = ZO_MostRecentPowerUpdateHandler:New("SlayerBars", function(...) self:OnPowerUpdate(...) end )
    updateHandler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)
    updateHandler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, self.unitTag)

	self.leadshineIdle:PlayFromStart()
	self:RegisterImpactfulHit()
end


function StackedBar:RegisterImpactfulHit()
	-- dummy event since there's no way to detect boss hit, would have to do combt event instead
	self.leadshineHitAnim = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsHitIndicatorAnimation", self.leadshine)
	
	SlayerBars.diamondIndicatorZoomOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("SlayerBarsDiamondZoomOut", SlayerBarDiamondIndicator)

	-- self.control:RegisterForEvent(EVENT_IMPACTFUL_HIT, function(_, ...) self:OnImpactfulHit(...) end )
	-- Player -> Target
	self.control:RegisterForEvent(EVENT_COMBAT_EVENT, function (_, ...) self:CombatOutgoing(_, ...) end)
	self.control:AddFilterForEvent(EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

function StackedBar:CombatOutgoing(result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
	local test = debounce( function() 
			self.leadshineHitAnim:PlayFromStart()
			SlayerBars.diamondIndicatorZoomOut:PlayFromStart()
		end, 800 )
	if result == ACTION_RESULT_CRITICAL_DAMAGE or ACTION_RESULT_DOT_TICK_CRITICAL then
		test()
	end
end

function StackedBar:OnPowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	self.bar:SetMinMax(0, powerMax)
	self.nameLabel:SetText(GetUnitName(unitTag) or "blank")
    self:SetValue(powerValue)
end

function StackedBar:SetMinMax(mn, mx)
	self.bar:SetMinMax(mn,mx)
end

function StackedBar:SetValue(value)
	local mn, mx = self.bar:GetMinMax()
	local chunk = mx / self.barCount
	
	local remainder = math.fmod(value, chunk)
	local percentPos = 0.0001 -- epsilon floating point 0
	if remainder < percentPos and value > 0 then
		percentPos = 1.0
	else
		percentPos = remainder / chunk
	end
	local pseudoval = percentPos * mx
	self.bar:SetValue(pseudoval)
	local bucketWidth = self.barCount / #PEEL_COLORS
	local currentBar = zo_ceil(value / mx * self.barCount)
	
	local colorSelect = zo_floor(currentBar / bucketWidth)
	local nextColor = zo_floor((currentBar - 1) / bucketWidth)
	
	if self.barCount < #PEEL_COLORS then
		colorSelect = colorSelect - 1
		nextColor = colorSelect - 1
	end

	ZO_StatusBar_SetGradientColor(self.bar, PEEL_COLORS[colorSelect])
	if currentBar <= 1 then
		self.backlayer:SetHidden(true)
		self.bucketNumber:SetHidden(true)
	else
		self.backlayer:SetHidden(false)
		self.bucketNumber:SetHidden(false)
		self.bucketNumber:SetText("x"..currentBar)
		ZO_StatusBar_SetGradientColor(self.backlayer, PEEL_COLORS[nextColor])
	end

	if value == 0 then
		self.leadshine:SetHidden(true)
	else
		self.leadshine:SetHidden(false)
		self.leadshine:ClearAnchors()
		self.leadshine:SetAnchor(CENTER, self.bar, LEFT, percentPos * self.bar:GetWidth(), 0)
	end
	self.resourceNumbers:SetText(ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, false).." ("..FormatPercent(value, mx).."%)")
end

local function OnPlayerZoneChange()
    if (GetCurrentZoneHouseId() > 0) then
        SlayerBars:RegisterForEvent(EVENT_RETICLE_TARGET_CHANGED, function() end)
    else
        SlayerBars:UnregisterForEvent(EVENT_RETICLE_TARGET_CHANGED)
    end
end


function SlayerBars.OnCombatState(_, inCombat)
	local UpdateEventName = SlayerBars.name .. "Update"
	
	if inCombat then
		EVENT_MANAGER:RegisterForUpdate(UpdateEventName, 100, SlayerBars.OnUpdate)
	else
		EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
	end
end

function SlayerBars.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)
    if effectName == "Off Balance Immunity" then
		d(iconName .. ", " .. abilityId .. ", " .. buffType)
	end

end

function SlayerBars.OnUpdate()
	for i = 1, GetNumBuffs("reticleover") do
		-- GRAB THE BUFF NAME INSTEAD OF THE ID
		local buffName, _, timeEnding = GetUnitBuffInfo("reticleover", i)

		if buffName == "Off Balance" then
		end
	end
end

local function OnLoaded(_, name)
    if name ~= SlayerBars.name then return end
    local value, max = GetUnitPower("player", POWERTYPE_STAMINA)
	local MAIN_BAR = StackedBar:New("reticleover", SlayerBarMain)
	local f = ZO_SimpleSceneFragment:New(SlayerBar)
	HUD_SCENE:AddFragment(f)
	HUD_UI_SCENE:AddFragment(f)
	EVENT_MANAGER:RegisterForEvent(SlayerBars.name, EVENT_PLAYER_COMBAT_STATE, SlayerBars.OnCombatState)
	EVENT_MANAGER:RegisterForEvent(SlayerBars.name, EVENT_EFFECT_CHANGED, SlayerBars.OnEffectChanged)
    -- EVENT_MANAGER:RegisterForEvent(OBT.name, EVENT_EFFECT_CHANGED, OBT.OnEffectChanged)
    -- EVENT_MANAGER:RegisterForEvent(OBT.name, EVENT_GROUP_MEMBER_ROLE_CHANGED, OBT.UpdateVisibility)
	-- SlayerBar:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function() OnPlayerZoneChange(MAIN_BAR) end)
	EVENT_MANAGER:UnregisterForEvent(EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(SlayerBars.name, EVENT_ADD_ON_LOADED, OnLoaded)