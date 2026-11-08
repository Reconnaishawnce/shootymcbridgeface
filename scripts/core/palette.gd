class_name Palette
extends RefCounted
## The game's colours in one place, chosen for punch and for reading at
## a glance on a phone: a saturated blue bridge deck over teal water,
## cream curbs and yellow lines, hot red crowds, blue soldiers, gold
## for money, purple for power. Pure; the scene scripts take their
## constants from here, and the tests hold the contrasts.

# The bridge.
const ROAD := Color(0.13, 0.3, 0.62)
const ROAD_CRACK := Color(0.07, 0.17, 0.38)
const CURB := Color(0.93, 0.92, 0.86)
const DASH := Color(1.0, 0.88, 0.25)
const POST := Color(0.12, 0.15, 0.22)
const DECK_SIDE := Color(0.09, 0.16, 0.3)
const WALK := Color(0.58, 0.6, 0.6)
const PIER := Color(0.3, 0.26, 0.22)
# The water and the far shore.
const WATER_DEEP := Color(0.04, 0.24, 0.45)
const WATER_LIGHT := Color(0.12, 0.5, 0.72)
const FOAM := Color(0.8, 0.93, 1.0)
const SHORE := Color(0.3, 0.42, 0.3)
const BUILDING := Color(0.14, 0.17, 0.26)
const WINDOW := Color(1.0, 0.78, 0.4)
const WRECKS := [Color(0.85, 0.2, 0.18), Color(0.15, 0.5, 0.6), Color(0.95, 0.75, 0.2), Color(0.2, 0.45, 0.3)]
# The sky and the light.
const SKY_TOP := Color(0.08, 0.3, 0.72)
const SKY_HORIZON := Color(0.95, 0.74, 0.58)
const GROUND_HORIZON := Color(0.25, 0.45, 0.6)
const GROUND_BOTTOM := Color(0.05, 0.12, 0.22)
const FOG := Color(0.72, 0.78, 0.9)
const SUN := Color(1.0, 0.94, 0.8)
const FILL := Color(0.4, 0.6, 1.0)
# People.
const SOLDIER := Color(0.16, 0.48, 0.98)
const ZOMBIE := Color(0.86, 0.2, 0.18)
const ZOMBIE_PALE := Color(0.96, 0.42, 0.3)
const BRUTE := Color(0.58, 0.08, 0.12)
const RUNNER := Color(1.0, 0.5, 0.18)
const THIEF := Color(0.98, 0.82, 0.25)
const TANK := Color(0.36, 0.4, 0.52)
const LATCHER := Color(0.78, 0.28, 0.78)
const SPLITTER := Color(0.72, 0.85, 0.28)
# Panels: lit signs.
const GOOD := Color(0.12, 0.5, 1.0, 0.9)
const BAD := Color(1.0, 0.18, 0.2, 0.9)
const HIDDEN := Color(0.45, 0.45, 0.55, 0.9)
const POWER := Color(0.62, 0.28, 1.0, 0.9)
const THINK := Color(0.1, 0.78, 0.72, 0.9)
const DEAL := Color(1.0, 0.6, 0.1, 0.9)
const CONVOY := Color(0.55, 0.62, 0.35, 0.92)
const SUPPLY := Color(1.0, 0.8, 0.15, 0.92)
const PANEL_FRAME := Color(0.06, 0.07, 0.12)
# Ink.
const INK := Color(0.03, 0.03, 0.07)
const INK_WIDTH := 0.036


## Perceived brightness, 0 to 1.
static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## How far apart two colours sit in hue, 0 to 0.5.
static func hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)


## Saturation of a colour, 0 to 1.
static func chroma(c: Color) -> float:
	return c.s
