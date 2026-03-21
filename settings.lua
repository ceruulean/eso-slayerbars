SlayerBars = SlayerBars or {}
local SB = SlayerBars
local LAM = LibAddonMenu2
local panelName = "SlayerBarsSettingsPanel"

local LMP = LibMediaProvider or {}
local is_previewing = false

function GetTableKeys(tab)
  local keyset = {}
  for k,v in pairs(tab) do
    keyset[#keyset + 1] = k
  end
  return keyset
end

local BACKDROP_CHOICES = {
	"ZO_DefaultBackdrop", "ZO_FrameBackdrop",
	"ZO_SelectionFrameBackdrop", "ZO_HighlightFrameBackdrop", "ZO_DarkThinFrame", "ZO_ThinBackdrop",
}

local savedVersion = 1
local DEFAULTS = {
  backdropStyle = BACKDROP_CHOICES[2],
  targetBarWidth = 500,
  targetBarHeight = 25,
  positions = {},
  targetNameFont = { "Univers 67", 20, "soft-shadow-thick" }
}

local function ShowPreviewBars()
	local lastChild
	local count = 10
	local spacing = SB.sv.targetBarHeight + SB.sv.targetNameFont[2]
	GAME_MENU_SCENE:AddFragment(SB.other_bars_frag)

	for i = count, 1, -1 do
		local stkd, key = SB.pool:AcquireObject()
		SB.activeBars[key] = stkd
		stkd.control:SetHidden(false)
		stkd:SetMinMax(0, 100)
		stkd:SetStacks(10)
		stkd:SetValue(i * 10 - 1)
		stkd.control:ClearAnchors()
		if lastChild then
			stkd.control:SetAnchor(TOP, lastChild.control, BOTTOM, 0, spacing)
		else
			stkd.control:SetAnchor(TOPCENTER, SlayerBarsOtherBars, TOPCENTER, 0, 0)
		end
		lastChild = stkd
	end
	SlayerBarsOtherBars:SetMovable(true)
	SlayerBarsOtherBars:SetDimensions(SB.sv.targetBarWidth, count * SB.sv.targetBarHeight + (count - 1) * SB.sv.targetNameFont[2])
end

local function UpdatePreviewBars()
	for k, v in ipairs(SB.activeBars) do
		v:UpdateStyle()
	end
end

local function HidePreviewBars()
	SB.pool:ReleaseAllObjects()
	SlayerBarsOtherBars:SetMovable(false)
	GAME_MENU_SCENE:RemoveFragment(SB.other_bars_frag)
end

local function LivePreview()
	if SB.is_unlocked then
		SB.UpdateMainBar()
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
		type = "header",
		name = "Target Frame",
		tooltip = "Adjust the target boss frames."
	},
	{
		type = "dropdown",
		name = "Backdrop Style",
		tooltip = "The border style",
		choices = BACKDROP_CHOICES,
		getFunc = function() return SB.sv.backdropStyle end,
		setFunc = function(val)
			SB.sv.backdropStyle = val
			LivePreview()
		end,
		default = DEFAULTS.backdropStyle
	},
	{
		type = "dropdown",
		name = "Target Name Font",
		sort = "name-up",
		choices = LMP:List(LMP.MediaType.FONT),
		getFunc = function() return SB.sv.targetNameFont[1] end,
		setFunc = function(val)
			SB.sv.targetNameFont[1] = val
			LivePreview()
		end,
		default = DEFAULTS.targetNameFont[1],
		width = "half"
	},
	{
		type = "slider",
		name = "Target Name Font Size",
		getFunc = function() return SB.sv.targetNameFont[2] end,
		setFunc = function(val)
			SB.sv.targetNameFont[2] = val
			LivePreview()
		end,
		min = 0,
		max = 50,
		default = DEFAULTS.targetNameFont[2],
		width = "half"
	},
	{
		type = "dropdown",
		name = "Bar Texture",
		width = "half"
	},
	{
		type = "dropdown",
		name = "Backlayer Texture",
		width = "half"
	},
	{
		type = "slider",
		name = "Bar Width",
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
		name = "Bar Height",
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
        {
            type = "button",
            name = "Preview Stacks",
            tooltip = "Preview Stack Colors",
            func = function()
                if is_previewing then
					HidePreviewBars()
				else
					ShowPreviewBars()
				end
				is_previewing = not is_previewing
            end,
            width = "half"
        },
}

function SlayerBars.InitSettingsMenu()
	SB.sv = ZO_SavedVars:NewAccountWide("SlayerBarsSavedVariables", savedVersion, nil, DEFAULTS)
	-- SlayerBars.savedVariablesChar = ZO_SavedVars:NewCharacterIdSettings("SlayerBarsSavedVariables", 2, nil, OCH.charSettings)
	LuiMedia:Initialize()

	local SBpanel = LAM:RegisterAddonPanel(panelName, {
		type = "panel",
		name = SB.displayName,
		version = SB.version,
		author = "ceruulean",
		registerForRefresh = true,
        registerForDefaults = true,
	})

	LAM:RegisterOptionControls(panelName, optionsData)

	-- CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
	-- if panel ~= SBpanel then return end
		-- ShowPreviewBars()
	-- end)

	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
	if panel ~= SBpanel then return end
		HidePreviewBars()
		is_previewing = false
		SB.UpdateMainBar()
	end)
end

