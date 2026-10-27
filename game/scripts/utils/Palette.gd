class_name Palette
extends RefCounted

## Palette — the one place for player, ticket and UI colours and icon textures,
## so the board, HUD and menus always agree.

const PLAYER: Dictionary = {
	0: Color("#8B5CF6"), # Mr. X
	1: Color("#EF4444"),
	2: Color("#3B82F6"),
	3: Color("#22C55E"),
	4: Color("#F59E0B"),
	5: Color("#EC4899"),
}

const TICKET: Dictionary = {
	"taxi": Color("#F5C542"),
	"bus": Color("#3BC48A"),
	"underground": Color("#E8457A"),
	"ferry": Color("#5AA9F0"),
	"black": Color("#C9CCD6"),
	"double": Color("#8B5CF6"),
}

const GOLD := Color("#FFC23D")
const RED := Color("#FF4D6A")
const TEXT := Color("#F4F6FB")
const MUTED := Color("#97A3BD")
const INK := Color("#0E1424")

const ICON: Dictionary = {
	"taxi": preload("res://game/assets/sprites/single/ui/icons/taxi.svg"),
	"bus": preload("res://game/assets/sprites/single/ui/icons/bus.svg"),
	"underground": preload("res://game/assets/sprites/single/ui/icons/metro.svg"),
	"ferry": preload("res://game/assets/sprites/single/ui/icons/ferry.svg"),
	"black": preload("res://game/assets/sprites/single/ui/icons/black.svg"),
	"double": preload("res://game/assets/sprites/single/ui/icons/double.svg"),
	"eye": preload("res://game/assets/sprites/single/ui/icons/eye.svg"),
	"eye_closed": preload("res://game/assets/sprites/single/ui/icons/eye_closed.svg"),
	"mask": preload("res://game/assets/sprites/single/ui/icons/mask.svg"),
	"detective": preload("res://game/assets/sprites/single/ui/icons/detective.svg"),
	"human": preload("res://game/assets/sprites/single/ui/icons/human.svg"),
	"robot": preload("res://game/assets/sprites/single/ui/icons/robot.svg"),
	"trophy": preload("res://game/assets/sprites/single/ui/icons/trophy.svg"),
	"phone": preload("res://game/assets/sprites/single/ui/icons/phone.svg"),
	"warning": preload("res://game/assets/sprites/single/ui/icons/warning.svg"),
}

static func player(index: int) -> Color:
	return PLAYER.get(index, Color.WHITE)

static func ticket(t: String) -> Color:
	return TICKET.get(t, Color.WHITE)

static func icon(key: String) -> Texture2D:
	return ICON.get(key, null)

static func player_icon(index: int) -> Texture2D:
	return ICON["mask"] if index == 0 else ICON["detective"]
