-- Types for the style rule tables passed to SetRule in Markup/Styles.luau.
-- Generated from luau-lsp's Roblox definitions, so it only lists properties that exist.
-- Every value can also be a token string such as "$Padding".
-- Types must be exported to be visible outside a definition file.

export type StyleToken = string

export type UIPaddingStyle = {
	PaddingBottom: (UDim | StyleToken)?,
	PaddingLeft: (UDim | StyleToken)?,
	PaddingRight: (UDim | StyleToken)?,
	PaddingTop: (UDim | StyleToken)?,
}

export type UICornerStyle = {
	BottomLeftRadius: (UDim | StyleToken)?,
	BottomRightRadius: (UDim | StyleToken)?,
	CornerRadius: (UDim | StyleToken)?,
	TopLeftRadius: (UDim | StyleToken)?,
	TopRightRadius: (UDim | StyleToken)?,
}

export type UIStrokeStyle = {
	ApplyStrokeMode: (Enum.ApplyStrokeMode | StyleToken)?,
	BorderOffset: (UDim | StyleToken)?,
	BorderStrokePosition: (Enum.BorderStrokePosition | StyleToken)?,
	Color: (Color3 | StyleToken)?,
	Enabled: (boolean | StyleToken)?,
	LineJoinMode: (Enum.LineJoinMode | StyleToken)?,
	StrokeSizingMode: (Enum.StrokeSizingMode | StyleToken)?,
	Thickness: (number | StyleToken)?,
	Transparency: (number | StyleToken)?,
	ZIndex: (number | StyleToken)?,
}

export type UIListLayoutStyle = {
	FillDirection: (Enum.FillDirection | StyleToken)?,
	HorizontalAlignment: (Enum.HorizontalAlignment | StyleToken)?,
	HorizontalFlex: (Enum.UIFlexAlignment | StyleToken)?,
	ItemLineAlignment: (Enum.ItemLineAlignment | StyleToken)?,
	Padding: (UDim | StyleToken)?,
	SortOrder: (Enum.SortOrder | StyleToken)?,
	VerticalAlignment: (Enum.VerticalAlignment | StyleToken)?,
	VerticalFlex: (Enum.UIFlexAlignment | StyleToken)?,
	Wraps: (boolean | StyleToken)?,
}

export type UIGridLayoutStyle = {
	CellPadding: (UDim2 | StyleToken)?,
	CellSize: (UDim2 | StyleToken)?,
	FillDirection: (Enum.FillDirection | StyleToken)?,
	FillDirectionMaxCells: (number | StyleToken)?,
	HorizontalAlignment: (Enum.HorizontalAlignment | StyleToken)?,
	SortOrder: (Enum.SortOrder | StyleToken)?,
	StartCorner: (Enum.StartCorner | StyleToken)?,
	VerticalAlignment: (Enum.VerticalAlignment | StyleToken)?,
}

export type UIFlexItemStyle = {
	FlexMode: (Enum.UIFlexMode | StyleToken)?,
	GrowRatio: (number | StyleToken)?,
	ItemLineAlignment: (Enum.ItemLineAlignment | StyleToken)?,
	ShrinkRatio: (number | StyleToken)?,
}

export type UISizeConstraintStyle = {
	MaxSize: (Vector2 | StyleToken)?,
	MinSize: (Vector2 | StyleToken)?,
}

export type UITextSizeConstraintStyle = {
	MaxTextSize: (number | StyleToken)?,
	MinTextSize: (number | StyleToken)?,
}

export type UIAspectRatioConstraintStyle = {
	AspectRatio: (number | StyleToken)?,
	AspectType: (Enum.AspectType | StyleToken)?,
	DominantAxis: (Enum.DominantAxis | StyleToken)?,
}

export type UIGradientStyle = {
	Color: (ColorSequence | StyleToken)?,
	Enabled: (boolean | StyleToken)?,
	Offset: (Vector2 | StyleToken)?,
	Rotation: (number | StyleToken)?,
	Scale: (number | StyleToken)?,
	TileMode: (Enum.GradientTileMode | StyleToken)?,
	Transparency: (NumberSequence | StyleToken)?,
	Type: (Enum.GradientType | StyleToken)?,
}

export type UIScaleStyle = {
	Scale: (number | StyleToken)?,
}

export type StyleProps = {
	-- Default transition for every property in the rule
	Transition: TweenInfo?,

	-- Pseudo-instances the rule creates inside matching elements
	["::UIPadding"]: UIPaddingStyle?,
	["::UICorner"]: UICornerStyle?,
	["::UIStroke"]: UIStrokeStyle?,
	["::UIListLayout"]: UIListLayoutStyle?,
	["::UIGridLayout"]: UIGridLayoutStyle?,
	["::UIFlexItem"]: UIFlexItemStyle?,
	["::UISizeConstraint"]: UISizeConstraintStyle?,
	["::UITextSizeConstraint"]: UITextSizeConstraintStyle?,
	["::UIAspectRatioConstraint"]: UIAspectRatioConstraintStyle?,
	["::UIGradient"]: UIGradientStyle?,
	["::UIScale"]: UIScaleStyle?,

	Active: (boolean | StyleToken)?,
	AnchorPoint: (Vector2 | StyleToken)?,
	AutoButtonColor: (boolean | StyleToken)?,
	AutomaticCanvasSize: (Enum.AutomaticSize | StyleToken)?,
	AutomaticSize: (Enum.AutomaticSize | StyleToken)?,
	BackgroundColor3: (Color3 | StyleToken)?,
	BackgroundTransparency: (number | StyleToken)?,
	BorderColor3: (Color3 | StyleToken)?,
	BorderMode: (Enum.BorderMode | StyleToken)?,
	BorderSizePixel: (number | StyleToken)?,
	BottomImage: (string | StyleToken)?,
	BottomImageContent: (Content | StyleToken)?,
	CanvasPosition: (Vector2 | StyleToken)?,
	CanvasSize: (UDim2 | StyleToken)?,
	ClearTextOnFocus: (boolean | StyleToken)?,
	CursorPosition: (number | StyleToken)?,
	ElasticBehavior: (Enum.ElasticBehavior | StyleToken)?,
	Font: (Enum.Font | StyleToken)?,
	FontFace: (Font | StyleToken)?,
	GroupColor3: (Color3 | StyleToken)?,
	GroupTransparency: (number | StyleToken)?,
	HorizontalScrollBarInset: (Enum.ScrollBarInset | StyleToken)?,
	HoverHapticEffect: (HapticEffect | StyleToken)?,
	HoverImage: (string | StyleToken)?,
	HoverImageContent: (Content | StyleToken)?,
	Image: (string | StyleToken)?,
	ImageColor3: (Color3 | StyleToken)?,
	ImageContent: (Content | StyleToken)?,
	ImageRectOffset: (Vector2 | StyleToken)?,
	ImageRectSize: (Vector2 | StyleToken)?,
	ImageTransparency: (number | StyleToken)?,
	InputSink: (Enum.InputSink | StyleToken)?,
	Interactable: (boolean | StyleToken)?,
	LayoutOrder: (number | StyleToken)?,
	LineHeight: (number | StyleToken)?,
	LocalizedText: (string | StyleToken)?,
	MaxVisibleGraphemes: (number | StyleToken)?,
	MidImage: (string | StyleToken)?,
	MidImageContent: (Content | StyleToken)?,
	Modal: (boolean | StyleToken)?,
	MultiLine: (boolean | StyleToken)?,
	OpenTypeFeatures: (string | StyleToken)?,
	OpenTypeFeaturesError: (string | StyleToken)?,
	PlaceholderColor3: (Color3 | StyleToken)?,
	PlaceholderText: (string | StyleToken)?,
	Position: (UDim2 | StyleToken)?,
	PressHapticEffect: (HapticEffect | StyleToken)?,
	PressedImage: (string | StyleToken)?,
	PressedImageContent: (Content | StyleToken)?,
	ResampleMode: (Enum.ResamplerMode | StyleToken)?,
	RichText: (boolean | StyleToken)?,
	Rotation: (number | StyleToken)?,
	ScaleType: (Enum.ScaleType | StyleToken)?,
	ScrollBarImageColor3: (Color3 | StyleToken)?,
	ScrollBarImageTransparency: (number | StyleToken)?,
	ScrollBarThickness: (number | StyleToken)?,
	ScrollingDirection: (Enum.ScrollingDirection | StyleToken)?,
	ScrollingEnabled: (boolean | StyleToken)?,
	Selectable: (boolean | StyleToken)?,
	Selected: (boolean | StyleToken)?,
	SelectionStart: (number | StyleToken)?,
	ShowNativeInput: (boolean | StyleToken)?,
	Size: (UDim2 | StyleToken)?,
	SizeConstraint: (Enum.SizeConstraint | StyleToken)?,
	SliceCenter: (Rect | StyleToken)?,
	SliceScale: (number | StyleToken)?,
	Style: (Enum.FrameStyle | Enum.ButtonStyle | StyleToken)?,
	Text: (string | StyleToken)?,
	TextColor3: (Color3 | StyleToken)?,
	TextDirection: (Enum.TextDirection | StyleToken)?,
	TextEditable: (boolean | StyleToken)?,
	TextScaled: (boolean | StyleToken)?,
	TextSize: (number | StyleToken)?,
	TextStrokeColor3: (Color3 | StyleToken)?,
	TextStrokeTransparency: (number | StyleToken)?,
	TextTransparency: (number | StyleToken)?,
	TextTruncate: (Enum.TextTruncate | StyleToken)?,
	TextWrapped: (boolean | StyleToken)?,
	TextXAlignment: (Enum.TextXAlignment | StyleToken)?,
	TextYAlignment: (Enum.TextYAlignment | StyleToken)?,
	TileSize: (UDim2 | StyleToken)?,
	TopImage: (string | StyleToken)?,
	TopImageContent: (Content | StyleToken)?,
	VerticalScrollBarInset: (Enum.ScrollBarInset | StyleToken)?,
	VerticalScrollBarPosition: (Enum.VerticalScrollBarPosition | StyleToken)?,
	Visible: (boolean | StyleToken)?,
	ZIndex: (number | StyleToken)?,

	-- Nested selectors, such as ":Hover"
	[string]: StyleProps,
}
