class_name Palette
extends RefCounted
## Single source of truth for colours. Scheme from the Adobe Color export "muss_management".

const SKY := Color("85BAEA")     # calm / good / selection
const ALERT := Color("EB271C")   # urgent
const BLOOD := Color("99251F")   # damage / bad
const SLATE := Color("42576B")   # structure
const INK := Color("202C2D")     # background
const MOSS := Color("767865")    # neutral / muted

# Derived shades (kept inside the scheme's hue family)
const INK_DEEP := Color("141C1D")
const PANEL := Color("263436")
const PANEL_LIGHT := Color("304246")
const TEXT := Color("E4ECEE")
const TEXT_DIM := Color("94A8AC")


static func meter_color(value: float, bad_when_high: bool) -> Color:
	var badness: float = value / 100.0 if bad_when_high else 1.0 - value / 100.0
	if badness < 0.45:
		return SKY
	if badness < 0.65:
		return MOSS.lightened(0.15)
	if badness < 0.82:
		return BLOOD
	return ALERT


static func room_tint(function_key: String) -> Color:
	match function_key:
		"office":
			return SLATE
		"break":
			return MOSS.darkened(0.15)
		"lounge":
			return SLATE.lerp(MOSS, 0.5)
		"interview":
			return SLATE.darkened(0.2)
		"mediation":
			return BLOOD.darkened(0.45)
		"locked":
			return INK
		_:
			return INK.lightened(0.1)
