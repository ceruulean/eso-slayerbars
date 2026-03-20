SlayerBars = SlayerBars or {}
local SB = SlayerBars
local LAM = LibAddonMenu2
local panelName = "SlayerBarsSettingsPanel"

local function LivePreview()
	if SB.is_unlocked then
		SB.UpdateMainBar()
	end
end

local BACKDROP_STYLES = {
	"ZO_DefaultBackdrop", "ZO_FrameBackdrop",
	"ZO_SelectionFrameBackdrop", "ZO_HighlightFrameBackdrop", "ZO_DarkThinFrame", "ZO_ThinBackdrop",
}

local savedVersion = 1
local DEFAULTS = {
  backdropStyle = BACKDROP_STYLES[2],
  targetBarWidth = 500,
  targetBarHeight = 25,
  positions = {}
}

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
				if newValue then
					SB.Unlock()
				else
					SB.Lock()
				end
            end,
            width = "half",
			default = false
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
		type = "dropdown",
		name = "Backdrop Style",
		tooltip = "The border style",
		choices = BACKDROP_STYLES,
		getFunc = function() return SB.sv.backdropStyle end,
		setFunc = function(val)
			SB.sv.backdropStyle = val
			LivePreview()
		end,
		default = DEFAULTS.backdropStyle
	},
	{
		type = "header",
		name = "Target Frame",
		tooltip = "Adjust the target boss frames."
	},
	{
		type = "slider",
		name = "Width",
		getFunc = function() return SB.sv.targetBarWidth end,
		setFunc = function(val)
			SB.sv.targetBarWidth = val
			LivePreview()
		end,
		min = 50,
		max = 1500,
		step = 5,
		default = DEFAULTS.targetBarWidth,
		width = "half"
	},
	{
		type = "slider",
		name = "Height",
		getFunc = function() return SB.sv.targetBarHeight end,
		setFunc = function(val)
			SB.sv.targetBarHeight = val
			LivePreview()
		end,
		min = 10,
		max = 50,
		default = DEFAULTS.targetBarHeight,
		width = "half"
	},
	{
		type = "divider",
		height = 5,
		alpha = 1,
		width = "full"
	},
}

function SlayerBars.InitSettingsMenu()
	SB.sv = ZO_SavedVars:NewAccountWide("SlayerBarsSavedVariables", savedVersion, nil, DEFAULTS)
	-- SlayerBars.savedVariablesChar = ZO_SavedVars:NewCharacterIdSettings("SlayerBarsSavedVariables", 2, nil, OCH.charSettings)

	local SBpanel = LAM:RegisterAddonPanel(panelName, {
		type = "panel",
		name = SB.displayName,
		version = SB.version,
		author = "ceruulean",
		registerForRefresh = true,
        registerForDefaults = true,
	})
	LAM:RegisterOptionControls(panelName, optionsData)
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
	if panel ~= SBpanel then return end
		SB.UpdateMainBar()
	end)
end
