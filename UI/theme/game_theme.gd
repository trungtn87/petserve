class_name GameTheme
extends RefCounted


# =========================================================
# COLORS
# =========================================================

const BG: Color = Color("#0B1018")
const SURFACE: Color = Color("#131B27")
const SURFACE_LIGHT: Color = Color("#1A2534")

const TEXT_PRIMARY: Color = Color("#F3F4F6")
const TEXT_SECONDARY: Color = Color("#9CA7B8")
const TEXT_DISABLED: Color = Color("#657184")

const ACCENT: Color = Color("#7DD3FC")
const ACCENT_HOVER: Color = Color("#A5E3FC")
const ACCENT_PRESSED: Color = Color("#55BDEB")

const ERROR: Color = Color("#FB7185")

const BORDER: Color = Color(
	1.0,
	1.0,
	1.0,
	0.08
)


# =========================================================
# SIZES
# =========================================================

const FONT_TITLE: int = 30
const FONT_HEADING: int = 23
const FONT_BODY: int = 18
const FONT_SMALL: int = 15
const FONT_BUTTON: int = 18

const CORNER_RADIUS: int = 18


# =========================================================
# CREATE THEME
# =========================================================

static func create() -> Theme:
	var theme: Theme = Theme.new()

	_setup_labels(theme)
	_setup_buttons(theme)
	_setup_line_edits(theme)
	_setup_panels(theme)
	_setup_progress_bars(theme)

	return theme


# =========================================================
# LABEL
# =========================================================

static func _setup_labels(
	theme: Theme
) -> void:
	theme.set_color(
		"font_color",
		"Label",
		TEXT_PRIMARY
	)

	theme.set_color(
		"font_shadow_color",
		"Label",
		Color(0, 0, 0, 0)
	)

	theme.set_font_size(
		"font_size",
		"Label",
		FONT_BODY
	)


# =========================================================
# BUTTON
# =========================================================

static func _setup_buttons(
	theme: Theme
) -> void:
	theme.set_color(
		"font_color",
		"Button",
		TEXT_PRIMARY
	)

	theme.set_color(
		"font_hover_color",
		"Button",
		TEXT_PRIMARY
	)

	theme.set_color(
		"font_pressed_color",
		"Button",
		TEXT_PRIMARY
	)

	theme.set_color(
		"font_disabled_color",
		"Button",
		TEXT_DISABLED
	)

	theme.set_font_size(
		"font_size",
		"Button",
		FONT_BUTTON
	)


	var normal: StyleBoxFlat = (
		_make_box(
			SURFACE_LIGHT,
			BORDER,
			CORNER_RADIUS
		)
	)

	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14


	var hover: StyleBoxFlat = (
		_make_box(
			Color("#223044"),
			Color(
				1.0,
				1.0,
				1.0,
				0.13
			),
			CORNER_RADIUS
		)
	)

	hover.content_margin_left = 24
	hover.content_margin_right = 24
	hover.content_margin_top = 14
	hover.content_margin_bottom = 14


	var pressed: StyleBoxFlat = (
		_make_box(
			Color("#101822"),
			ACCENT,
			CORNER_RADIUS
		)
	)

	pressed.content_margin_left = 24
	pressed.content_margin_right = 24
	pressed.content_margin_top = 14
	pressed.content_margin_bottom = 14


	var disabled: StyleBoxFlat = (
		_make_box(
			Color("#111720"),
			Color(
				1.0,
				1.0,
				1.0,
				0.04
			),
			CORNER_RADIUS
		)
	)


	theme.set_stylebox(
		"normal",
		"Button",
		normal
	)

	theme.set_stylebox(
		"hover",
		"Button",
		hover
	)

	theme.set_stylebox(
		"pressed",
		"Button",
		pressed
	)

	theme.set_stylebox(
		"disabled",
		"Button",
		disabled
	)


# =========================================================
# LINE EDIT
# =========================================================

static func _setup_line_edits(
	theme: Theme
) -> void:
	theme.set_color(
		"font_color",
		"LineEdit",
		TEXT_PRIMARY
	)

	theme.set_color(
		"font_placeholder_color",
		"LineEdit",
		TEXT_SECONDARY
	)

	theme.set_color(
		"caret_color",
		"LineEdit",
		ACCENT
	)

	theme.set_color(
		"selection_color",
		"LineEdit",
		Color(
			0.49,
			0.83,
			0.99,
			0.30
		)
	)

	theme.set_font_size(
		"font_size",
		"LineEdit",
		FONT_BODY
	)


	var normal: StyleBoxFlat = (
		_make_box(
			SURFACE,
			BORDER,
			14
		)
	)

	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14


	var focus: StyleBoxFlat = (
		_make_box(
			SURFACE,
			ACCENT,
			14
		)
	)

	focus.content_margin_left = 18
	focus.content_margin_right = 18
	focus.content_margin_top = 14
	focus.content_margin_bottom = 14


	theme.set_stylebox(
		"normal",
		"LineEdit",
		normal
	)

	theme.set_stylebox(
		"focus",
		"LineEdit",
		focus
	)


# =========================================================
# PANEL
# =========================================================

static func _setup_panels(
	theme: Theme
) -> void:
	var panel: StyleBoxFlat = (
		_make_box(
			SURFACE,
			BORDER,
			CORNER_RADIUS
		)
	)

	theme.set_stylebox(
		"panel",
		"Panel",
		panel
	)

	theme.set_stylebox(
		"panel",
		"PanelContainer",
		panel
	)


# =========================================================
# PROGRESS BAR
# =========================================================

static func _setup_progress_bars(
	theme: Theme
) -> void:
	var background: StyleBoxFlat = (
		_make_box(
			Color("#202B39"),
			Color.TRANSPARENT,
			8
		)
	)


	var fill: StyleBoxFlat = (
		_make_box(
			ACCENT,
			Color.TRANSPARENT,
			8
		)
	)


	theme.set_stylebox(
		"background",
		"ProgressBar",
		background
	)

	theme.set_stylebox(
		"fill",
		"ProgressBar",
		fill
	)

	theme.set_color(
		"font_color",
		"ProgressBar",
		TEXT_PRIMARY
	)


# =========================================================
# HELPERS
# =========================================================

static func _make_box(
	background_color: Color,
	border_color: Color,
	radius: int
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()

	box.bg_color = background_color

	box.border_color = border_color

	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1

	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius

	return box
