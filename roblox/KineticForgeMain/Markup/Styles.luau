--!strict
--!optimize 2
--!native

local StyleTypes = require("../UIParser/StyleTypes") 

local coreSheet: StyleSheet = Instance.new("StyleSheet")
-- coreSheet.Parent = game.ReplicatedStorage:WaitForChild("Design")
coreSheet.Name = "RBXML"

-- Style tokens are attributes on the sheet. Rules reference one with a "$Name" string,
-- e.g. BackgroundColor3 = "$Accent", and update whenever the token changes
local function SetTokens(tokens: { [string]: any })
	for name, value in tokens do
		coreSheet:SetAttribute(name, value)
	end
end

type Rules = {
	[string]: StyleRule
}

-- Top-level rules by selector, filled in by SetRule
const rules: Rules = {}

-- Typing props gives completions and type checking in the rule tables below
local function SetRule(selector: string, props: StyleTypes.StyleProps, parent: StyleRule?): StyleRule
	local rule = Instance.new("StyleRule")

	if props.Transition then
		rule:SetDefaultPropertyTransition(props.Transition)
	end

	if selector:find(":Hover") then
		rule.Priority = 3
	else
		rule.Priority = 2
	end

	-- StyleProps only describes the keys, so walk it as a plain table
	for prop: string, value: any in props :: { [string]: any } do
		if prop == "Transition" then
			continue
		elseif typeof(value) == "table" then
			SetRule(prop, value, rule)
		else
			rule:SetProperty(prop, value)
		end
	end

	rule.Name = selector
	rule.Selector = selector
	rule.Parent = parent or coreSheet

	-- Nested selectors like "::UIPadding" repeat across parents, so only key top-level rules
	if not parent then
		rules[selector] = rule
	end

	return rule
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Names must be valid attribute names: letters, digits and underscores only
SetTokens({
	-- Accent = Color3.fromRGB(164, 58, 58),
	-- BodyFont = Font.fromEnum(Enum.Font.RobotoMono),
	Padding = UDim.new(0, 4),
	ButtonPadding = UDim.new(0, 8),
	CornerRadius = UDim.new(0, 4),
	ContainerColor = Color3.fromHex("#333333"),
	ContainerStrokeColor = Color3.fromRGB(164, 166, 177),
	ButtonStrokeColor = Color3.fromRGB(164, 166, 177),
	ButtonColor = Color3.fromHex("#333333"),
	TextColor = Color3.fromHex("#F5F5F5"),
	FontSize = 16
})

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Fills the widget and scrolls vertically when the content is taller than it. The frame
-- itself mustn't auto-size, or it grows with its content and never has anything to scroll.
SetRule(".main-container", {
	Size = UDim2.fromScale(1, 1),
	-- Children scale against the canvas, so its width follows the widget. Its height
	-- starts at 0 and AutomaticCanvasSize grows it to fit the content, instead of
	-- the default of twice the frame's height.
	CanvasSize = UDim2.fromScale(1, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 0
	-- BackgroundColor3 = Color3.new(0.643137, 0.227451, 0.227451),
})

SetRule(".disabled", {
	BackgroundTransparency = 0.5,
	TextTransparency = 0.5,
	Interactable = false,
})

SetRule(".container", {
	["::UIPadding"] = {
		PaddingLeft = "$Padding",
		PaddingRight = "$Padding",
		PaddingTop = "$Padding",
		PaddingBottom = "$Padding",
	},
	["::UICorner"] = {
		CornerRadius = "$CornerRadius"
	},
	["::UIStroke"] = {
		Color = "$ContainerStrokeColor",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	},

	BackgroundColor3 = "$ContainerColor",
	BackgroundTransparency = 0,
})

-- Instance.new("UIPadding").pa
SetRule(".textlabel,.textbox", {
	["::UIPadding"] = {
		PaddingLeft = "$Padding",
		PaddingRight = "$Padding",
		PaddingTop = "$Padding",
		PaddingBottom = "$Padding",
	},
	["::UICorner"] = {
		CornerRadius = "$CornerRadius",
	},

	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromScale(1, 0),
	TextWrapped = true,
	BackgroundTransparency = 1,
	FontFace = Font.fromEnum(Enum.Font.RobotoMono),
	TextSize = "$FontSize",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = "$TextColor"
})

SetRule(".textbutton", {
	["::UIPadding"] = {
		PaddingLeft = "$Padding",
		PaddingRight = "$Padding",
		PaddingTop = "$Padding",
		PaddingBottom = "$Padding",
	},
	["::UICorner"] = {
		CornerRadius = "$CornerRadius"
	},
	["::UIFlexItem"] = {
		FlexMode = Enum.UIFlexMode.Fill
	},
	["::UIStroke"] = {
		Color = "$ButtonStrokeColor",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	},

	-- Only grow in height. Growing in width lets a long label push the button past its
	-- container's padding instead of truncating.
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 0,
	FontFace = Font.fromEnum(Enum.Font.RobotoMono),
	TextSize = "$FontSize",
	TextTruncate = Enum.TextTruncate.AtEnd,
	BackgroundColor3 = "$ButtonColor",
	TextColor3 = "$TextColor"
})

-- For buttons in a vertical list. Fill also shrinks an item along its list's direction,
-- and a list in an auto-sized frame never has spare height, so it squeezes the button flat.
SetRule(".no-flex", {
	["::UIFlexItem"] = {
		FlexMode = Enum.UIFlexMode.None
	},
})

SetRule(".button-container", {
	["::UIPadding"] = {
		PaddingLeft = "$Padding",
		PaddingRight = "$Padding",
		PaddingTop = "$Padding",
		PaddingBottom = "$Padding",
	},
	["::UICorner"] = {
		CornerRadius = "$CornerRadius"
	},

	BackgroundColor3 = "$ContainerColor",
	Size = UDim2.fromScale(1, 0)
})

SetRule(".list-horizontal", {
	["::UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = "$Padding",
		HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	
	AutomaticSize = Enum.AutomaticSize.Y,
})

SetRule(".textbox", {
	-- Full width, fixed 200 px tall. Pasted data is long, so it shouldn't grow with its text.
	Size = UDim2.new(1, 0, 0, 100),
	AutomaticSize = Enum.AutomaticSize.None,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextYAlignment = Enum.TextYAlignment.Top
})

SetRule(".list-vertical", {
	["::UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = "$Padding",
		SortOrder = Enum.SortOrder.LayoutOrder,
		-- VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,
		-- Wraps = true,
	},
})

SetRule(".fill-xy", {
	Size = UDim2.fromScale(1, 1),
})

SetRule(".fill-x", {
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})

SetRule(".fill-y", {
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
})

-- SetRule(".font-roboto-mono", {
-- 	Font = Font.new("Roboto Mono")
-- })

-- SetRule(".fs-20", {
-- 	TextSize = 20
-- })

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

return coreSheet