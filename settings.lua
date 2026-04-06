SlayerBars = SlayerBars
local SB = SlayerBars
local LAM = LibAddonMenu2
local panelName = "SlayerBarsSettingsPanel"

local LMP = LibMediaProvider or {}
local is_previewing = false
local is_previewing_twins = false

function GetTableKeys(tab)
    local keyset = {}
    for k, v in pairs(tab) do
        keyset[#keyset + 1] = k
    end
    return keyset
end

function GetTableValues(tab)
    local keyset = {}
    for k, v in pairs(tab) do
        keyset[#keyset + 1] = v
    end
    return keyset
end

local BACKDROP_CHOICES = {
    "ZO_FrameBackdrop",
    "ZO_DefaultBackdrop",
    "ZO_SelectionFrameBackdrop",
    "ZO_HighlightFrameBackdrop",
    "ZO_DarkThinFrame",
    "ZO_ThinBackdrop",
    "ZO_MinorMungeBackdrop_SemiTransparentBlack",
    "ZO_CenterlessBackdrop",
    "ZO_GamepadAbilityIconFrame",
    "ZO_GamepadNormalOutlineHighlight",
    "ZO_GamepadNormalOutlineThin",
    "ZO_GamepadWhiteOutlineSelection"
}

local BAR_TEXT_CHOICES = {
    "Elder Scrolls Gradient",
    "ESO Basic",
    "Flat",
    "Healbot",
    "Inner Glow",
    "Inner Shadow",
    "Inner Shadow Glossy",
    "Minimalistic",
    "Outline",
    "Round",
    "Smooth",
    "Smooth v2",
    "Wglass"
}

local BACKLAYER_TEX_CHOICES = {
    "Armory",
    "BantoBar",
    "Cilo",
    "Empty",
    "ESO Basic",
    "Flat",
    "Graphite",
    "Inner Glow",
    "Inner Shadow",
    "Melli Dark",
    "Melli Dark Rough",
    "Minimalistic",
    "Otravi",
    "Smooth",
    "Smooth v2",
    "Shadow"
}

SB.Settings = {
    ADD_BOSS_DISPLAY_COMPACT = 1,
    ADD_BOSS_DISPLAY_LIST = 2
}

local ADD_BOSS_DISPLAY = {
    [SB.Settings.ADD_BOSS_DISPLAY_COMPACT] = "Compact",
    [SB.Settings.ADD_BOSS_DISPLAY_LIST] = "List"
}

local ADD_BOSS_DISPLAY_CHOICES = GetTableValues(ADD_BOSS_DISPLAY)

local RESOURCE_NUMBER_FORMATS = {RESOURCE_NUMBERS_SETTING_OFF, RESOURCE_NUMBERS_SETTING_NUMBER_ONLY, RESOURCE_NUMBERS_SETTING_PERCENT_ONLY, RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT}
local RESOURCE_NUMBER_CHOICES = {}
for i=1, #RESOURCE_NUMBER_FORMATS do
    table.insert(RESOURCE_NUMBER_CHOICES, GetString("SI_RESOURCENUMBERSSETTING", RESOURCE_NUMBER_FORMATS[i]))
end


local savedVersion = 1
local DEFAULTS = {
    debugMode = false,
    targetBarTex = "Inner Shadow Glossy",
    targetBacklayerTex = "Cilo",
    backdropStyle = BACKDROP_CHOICES[1],
    positions = {},
    primaryBarWidth = 500,
    primaryBarHeight = 25,
    primaryNameFont = {"Univers 67", 20, "soft-shadow-thick"},
    primaryResourceFont = {"Futura Condensed", 22, "soft-shadow-thick"},
    primaryResourceNumberFormat = RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT,
    addBossDisplayLayout = SB.Settings.ADD_BOSS_DISPLAY_COMPACT,
    addBossBarWidth = 500,
    addBossBarHeight = 20,
    addBossNameFont = {"Univers 67", 18, "soft-shadow-thick"},
    addBossResourceNumberFormat = RESOURCE_NUMBERS_SETTING_OFF,

}

local previewBar
local dummycount = 100
local function AutoValue()
    if not is_previewing then
        return
    end
    if dummycount % 10 == 0 and dummycount < 100 then
        previewBar:SetValue((dummycount * 10) + 0.1)
    elseif dummycount % 10 == 8 and dummycount < 98 then
        previewBar:SetValue((dummycount + 2) * 10)
    else
        previewBar:SetValue(dummycount * 10)
    end
    dummycount = dummycount - 2
    if dummycount < 0 then
        dummycount = 100
    end
    zo_callLater(
        function()
            AutoValue()
        end,
        500
    )
end

local function ShowPreviewBars()
    is_previewing = true
    local lastChild
    local count = 10
    local spacing = SB.sv.primaryBarHeight + SB.sv.primaryNameFont[2]
    GAME_MENU_SCENE:AddFragment(SB.other_bars_frag)
    previewBar = SB.instantiatedBars["boss1"]
    previewBar.control:SetHidden(false)
    previewBar:SetMinMax(0, 1000)
    previewBar:SetStacks(10)
    previewBar:SetValue(1000)
    SlayerBarsOtherBars:SetMovable(true)
    AutoValue()
end

local function UpdatePreviewBars()
    previewBar:UpdateStyle()
end

local function HidePreviewBars()
    is_previewing = false
end

local function LivePreview()
    if SB.is_unlocked then
        SB.UpdateAllBars()
    end
    if is_previewing then
        UpdatePreviewBars()
    end
end

local optionsData = {
    {
        type = "checkbox",
        name = "Unlock UI",
        tooltip = "Unlock to move the boss bar.",
        getFunc = function()
            return SB.is_unlocked
        end,
        setFunc = function(newValue)
            SB.is_unlocked = newValue
            SB.Unlock(newValue)
        end,
        width = "half"
    },
    {
        type = "button",
        name = "Reset Position",
        tooltip = "Reset boss bars to default position.",
        func = function()
            SB.ResetPosition()
        end,
        width = "half"
    },
    {
        type = "header",
        name = "Target Frame",
        tooltip = "Adjust the style of target frames."
    },
    {
        type = "dropdown",
        name = "Bar Texture",
        getFunc = function()
            return SB.sv.targetBarTex
        end,
        setFunc = function(val)
            SB.sv.targetBarTex = val
            LivePreview()
        end,
        choices = BAR_TEXT_CHOICES, -- LMP:List(LMP.MediaType.STATUSBAR)
        default = DEFAULTS.targetBarTex,
        width = "half"
    },
    {
        type = "dropdown",
        name = "Backlayer Texture",
        getFunc = function()
            return SB.sv.targetBacklayerTex
        end,
        setFunc = function(val)
            SB.sv.targetBacklayerTex = val
            LivePreview()
        end,
        choices = BACKLAYER_TEX_CHOICES, -- LMP:List(LMP.MediaType.STATUSBAR)
        default = DEFAULTS.targetBacklayerTex,
        width = "half"
    },
    {
        type = "dropdown",
        name = "Backdrop Style",
        tooltip = "The border style",
        choices = BACKDROP_CHOICES,
        getFunc = function()
            return SB.sv.backdropStyle
        end,
        setFunc = function(val)
            SB.sv.backdropStyle = val
            LivePreview()
        end,
        requiresReload = true,
        default = DEFAULTS.backdropStyle
    },
    {
        type = "submenu",
        name = "Primary Boss Bar",
        tooltip = "Adjust the primary boss bar.",
        controls = {
            {
                type = "button",
                name = "Preview Twins",
                tooltip = "Preview twin bars",
                func = function()
                    if is_previewing_twins then
                       SB.OnBossesChanged(_, true)
                       SB.Unlock(SB.is_unlocked)
                    else
                        SB.enemyTracker.twinFight = true
                        SB.UpdateDisplayLayout()
                    end
                    is_previewing_twins = not is_previewing_twins
                end,
                width = "half"
            },
            {
                type = "button",
                name = "Preview Stacks",
                tooltip = "Preview stack colors",
                func = function()
                    if is_previewing then
                        HidePreviewBars()
                    else
                        ShowPreviewBars()
                    end
                end,
                width = "half"
            },
            {
                type = "slider",
                name = "Bar Width",
                getFunc = function()
                    return SB.sv.primaryBarWidth
                end,
                setFunc = function(val)
                    SB.sv.primaryBarWidth = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                min = 50,
                max = 1500,
                step = 5,
                default = DEFAULTS.primaryBarWidth,
                width = "half"
            },
            {
                type = "slider",
                name = "Bar Height",
                getFunc = function()
                    return SB.sv.primaryBarHeight
                end,
                setFunc = function(val)
                    SB.sv.primaryBarHeight = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                min = 10,
                max = 50,
                default = DEFAULTS.primaryBarHeight,
                width = "half"
            },
            {
                type = "dropdown",
                name = "Primary Name Font",
                sort = "name-up",
                choices = LMP:List(LMP.MediaType.FONT),
                getFunc = function()
                    return SB.sv.primaryNameFont[1]
                end,
                setFunc = function(val)
                    SB.sv.primaryNameFont[1] = val
                    LivePreview()
                end,
                default = DEFAULTS.primaryNameFont[1],
                width = "half"
            },
            {
                type = "slider",
                name = "Text Size",
                getFunc = function()
                    return SB.sv.primaryNameFont[2]
                end,
                setFunc = function(val)
                    SB.sv.primaryNameFont[2] = val
                    LivePreview()
                end,
                min = 0,
                max = 50,
                default = DEFAULTS.primaryNameFont[2],
                width = "half"
            },
            -- reference = "MyAddonSubmenu"
            {
                type = "dropdown",
                name = GetString(SI_INTERFACE_OPTIONS_RESOURCE_NUMBERS),
                tooltip = "Format of health amount",
                getFunc = function()
                    return SB.sv.primaryResourceNumberFormat
                end,
                setFunc = function(val)
                    SB.sv.primaryResourceNumberFormat = val
                    LivePreview()
                end,
                choices = RESOURCE_NUMBER_CHOICES,
                choicesValues = RESOURCE_NUMBER_FORMATS,
                default = DEFAULTS.primaryResourceNumberFormat,
                width = "full"
            },
        }
    },
    {
        type = "submenu",
        name = "Additional Boss Bars",
        tooltip = "Adjust the display of additional boss bars.",
        controls = {
            {
                type = "dropdown",
                name = "Display Layout",
                getFunc = function()
                    return SB.sv.addBossDisplayLayout
                end,
                setFunc = function(val)
                    SB.sv.addBossDisplayLayout = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                choices = GetTableValues(ADD_BOSS_DISPLAY),
                choicesValues = GetTableKeys(ADD_BOSS_DISPLAY),
                default = DEFAULTS.addBossDisplayLayout,
                width = "full"
            },
            {
                type = "slider",
                name = "Bar Width",
                getFunc = function()
                    return SB.sv.addBossBarWidth
                end,
                setFunc = function(val)
                    SB.sv.addBossBarWidth = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                min = 50,
                max = 1000,
                step = 5,
                default = DEFAULTS.addBossBarWidth,
                width = "half"
            },
            {
                type = "slider",
                name = "Bar Height",
                getFunc = function()
                    return SB.sv.addBossBarHeight
                end,
                setFunc = function(val)
                    SB.sv.addBossBarHeight = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                min = 10,
                max = 50,
                default = DEFAULTS.addBossBarHeight,
                width = "half"
            },
            {
                type = "dropdown",
                name = "Additional Bosses Name Font",
                sort = "name-up",
                choices = LMP:List(LMP.MediaType.FONT),
                getFunc = function()
                    return SB.sv.addBossNameFont[1]
                end,
                setFunc = function(val)
                    SB.sv.addBossNameFont[1] = val
                    LivePreview()
                end,
                default = DEFAULTS.addBossNameFont[1],
                width = "half"
            },
            {
                type = "slider",
                name = "Text Size",
                getFunc = function()
                    return SB.sv.addBossNameFont[2]
                end,
                setFunc = function(val)
                    SB.sv.addBossNameFont[2] = val
                    SB.UpdateDisplayLayout()
                    LivePreview()
                end,
                min = 0,
                max = 40,
                default = DEFAULTS.addBossNameFont[2],
                width = "half"
            },
            {
                type = "dropdown",
                name = GetString(SI_INTERFACE_OPTIONS_RESOURCE_NUMBERS),
                tooltip = "Format of health amount",
                getFunc = function()
                    return SB.sv.addBossResourceNumberFormat
                end,
                setFunc = function(val)
                    SB.sv.addBossResourceNumberFormat = val
                    LivePreview()
                end,
                choices = RESOURCE_NUMBER_CHOICES,
                choicesValues = RESOURCE_NUMBER_FORMATS,
                default = DEFAULTS.addBossResourceNumberFormat,
                width = "full"
            },
        },
        -- reference = "MyAddonSubmenu"
    },
}
function SlayerBars.InitSettingsMenu()
    SB.sv = ZO_SavedVars:NewAccountWide("SlayerBarsSavedVariables", savedVersion, nil, DEFAULTS)
    -- SlayerBars.savedVariablesChar = ZO_SavedVars:NewCharacterIdSettings("SlayerBarsSavedVariables", 2, nil, OCH.charSettings)
    LuiMedia:Initialize()

    local SBpanel =
        LAM:RegisterAddonPanel(
        panelName,
        {
            type = "panel",
            name = SB.displayName,
            version = SB.version,
            author = "ceruulean",
            registerForRefresh = true,
            registerForDefaults = true
        }
    )

    LAM:RegisterOptionControls(panelName, optionsData)

    -- CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    -- if panel ~= SBpanel then return end
    -- ShowPreviewBars()
    -- end)

    CALLBACK_MANAGER:RegisterCallback(
        "LAM-PanelClosed",
        function(panel)
            if panel ~= SBpanel then
                return
            end
            HidePreviewBars()
            is_previewing = false
            is_previewing_twins = false
            SB.OnBossesChanged(_, true)
            SB.UpdateAllBars()
        end
    )
end
