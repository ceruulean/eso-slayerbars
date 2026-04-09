SlayerBars = SlayerBars or {}
local SB = SlayerBars
SB.name = "SlayerBars"
SB.displayName = "Slayer Bars"
SB.version = "0.1"

SB.STATE = {
        OOC_IDLE = 0,
        COMBAT_IDLE = 1,
        DIZZY = 2,
        TAUNTED = 3,
        TAUNT_SOON = 4,
        UNTAUNTED = 5
    }
SB.currentState = SB.STATE.OOC_IDLE
-----------------------------------------------------------
-- Register Abilities
-----------------------------------------------------------
SB.ability = {}
SB.ability[62988] = GetAbilityName(62988)
SB.ability[134599] = GetAbilityName(134599)
SB.OB_NAME = SB.ability[62988]
SB.OB_IMMUNE_NAME = SB.ability[134599]

-- from Untaunted and Srendaar addons
local AbilityCopies = {
    -- Minor Vulnerability
    [81519] = {51434,61782,68359,79715,79717,79720,79723,79726,79843,79844,79845,79846,117025,118613,120030,124803,124804,124806,130155,130168,130173,130809},
    -- Minor Lifesteal
    [80020] = {86304,86305,86307,88565,88575,88606,92653,121634,148043},
    -- Minor Fracture
    [64144] = {79090,79091,79309,79311,60416,84358},
    -- Minor Breach
    [68588] = {38688,61742,83031,84358,108825,120019,126685,146908},
    -- Off Balance
    [62988] = {23808,34117,71877,6150,163593,45834,104012,45902,130129,11474,154579,72279,130139,29598,137312,130145,214432,39077,100582,70054,25256,137257,131562,20806,117292,34733,14062,256815,211496,34737,186482,208859,37152,212853,125750,240504,62968,156183,120014,164731,241340,5805,62988,75214},
    -- Off Balance Immunity
    [134599] = {},
    -- Major Breach
    [62787] = {28307,33363,34386,36972,36980,40254,48946,53881,61743,62474,62485,62775,78609,85362,91175,91200,100988,108951,111788,117818,118438,120010},
    -- Major Vulnerability
    [122389] = {106754,106755,106758,106760,106762,122177,122397},
    -- Minor Magickasteal
    [39100] = {26220,26809,88401,88402,88576,125316,148044},
    -- Taunt
    [38541] = {38254},
}

local OB_EFFECTS = {
    icon = "/esoui/art/icons/ability_debuff_offbalance.dds",
    ob_ids = {62988},
    ob_immun_ids = {134599}
}

local function TableContains(tab, val)
    for key, value in pairs(tab) do
        if value == val then
            return true -- Found the value
        end
    end
    return false -- Value not found
end

SB.enemyTracker = {
    reticleUnitId = nil,
    byId = {}, -- [unitId] = { effects... }
    bossMap = {}, -- ["boss1"] = unitId
    bossHealth = {},
    twinFight = false,
    cloneFight = false,
}
local enemyTracker = SB.enemyTracker

local function TrackUnit(unitTag, unitId)
    if not unitId then
        return
    end
    enemyTracker.byId[unitId] = enemyTracker.byId[unitId] or {}

    if unitTag == "reticleover" then
        enemyTracker.reticleUnitId = unitId
    end
    if string.find(unitTag, "^boss%d+") then
        enemyTracker.bossMap[unitTag] = unitId
        enemyTracker.byId[unitId].unitTag = unitTag
    end
    -- CALLBACK_MANAGER:FireCallbacks('OnUnitTracked', unitId, unitTag)
end

function SB.UpdateScope()
    local currentRole = GetSelectedLFGRole()
    local isTank = currentRole == LFG_ROLE_TANK
    SlayerBarTrackerIconDemon:SetHidden(not isTank)
    SlayerBarTrackerIconDemonGlow:SetHidden(not isTank)
    SlayerBarTrackerDiamondIndicator:SetHidden(currentRole == LFG_ROLE_TANK)
end

local function OnReticleTargetChanged(eventId)
    local exists = DoesUnitExist("reticleover")
    SB.UpdateReticleTarget(exists)
    if not exists then
        enemyTracker.reticleUnitId = nil
    end
end

local function OnEffectChanged(eventId, changeType,    effectSlot,    effectName,    unitTag,    beginTime,    endTime,    stackCount,    iconName,    buffType,    effectType,    abilityType,    statusEffectType,    unitName,    unitId,    abilityId,    sourceUnitType)
    TrackUnit(unitTag, unitId)
    local currentTime = GetGameTimeSeconds()
    if effectName == SB.OB_NAME then
        if changeType == EFFECT_RESULT_GAINED then
            SB.enemyTracker.byId[unitId][effectName] = {0, beginTime, endTime}
        elseif changeType == EFFECT_RESULT_FADED then
            SB.enemyTracker.byId[unitId][effectName] = nil
        end
    elseif effectName == SB.OB_IMMUNE_NAME then
        if changeType == EFFECT_RESULT_GAINED then
            SB.enemyTracker.byId[unitId][effectName] = {0, beginTime, endTime}

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
            SB.enemyTracker.byId[unitId][effectName] = nil
            SlayerBarInkBgOffBalance:SetHidden(true)
        end
    end
end

local function OnPlayerZoneChanged(_)
    local UpdateEventName = SB.name .. "Update"
    if (GetCurrentZoneHouseId() > 0) then
        SB.RegisterDummy()
    else
        --EVENT_MANAGER:UnregisterForEvent(EVENT_RETICLE_TARGET_CHANGED)
        -- EVENT_MANAGER:UnregisterForUpdate(UpdateEventName)
        SB.UnregisterDummy()
        SB.OnBossesChanged(nil, true)
    end
end

local function OnLoaded(_, name)
    if name ~= SB.name then
        return
    end
    SB.is_console = IsConsoleUI()
    SB.InitSettingsMenu()
    SB.InitBars()
    SB.Anim.Init()
    SB.UpdateScope()
    SB.Unlock(SB.is_unlocked)
    COMPASS_FRAME:SetBossBarHiddenForReason(SB.name, true)
    EVENT_MANAGER:RegisterForEvent(SB.name .. "PlayerLoaded", EVENT_PLAYER_ACTIVATED, OnPlayerZoneChanged)
    EVENT_MANAGER:RegisterForEvent(SB.name .. "EffectChange", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:RegisterForEvent(SB.name .. "ReticleTarget", EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)

    EVENT_MANAGER:RegisterForEvent(SB.name .. "BossesChanged", EVENT_BOSSES_CHANGED, SB.OnBossesChanged)
    EVENT_MANAGER:RegisterForEvent(SB.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE, SB.OnCombatState)
    -- EVENT_MANAGER:RegisterForEvent(SB.name.."RoleSwap", EVENT_GROUP_MEMBER_ROLE_CHANGED, SB.OnRoleChanged)
    -- EVENT_MANAGER:AddFilterForEvent(SB.name.."RoleSwap", EVENT_GROUP_MEMBER_ROLE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    -- EVENT_MANAGER:RegisterForEvent(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() RefreshAllBosses(true) end)
    EVENT_MANAGER:UnregisterForEvent(EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(SB.name .. "AddonLoad", EVENT_ADD_ON_LOADED, OnLoaded)
