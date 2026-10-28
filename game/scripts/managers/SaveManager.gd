class_name SaveManager
extends Node

## SaveManager — Core Game-Facing Save Facade (GameService.save)
##
## Acts as the clean bridge between gameplay scripts and the backend 13-bucket
## Unified Game Data Model. Manages disk persistence, in-memory cache clearing,
## transactions, and cloud synchronization.
##
## Devs can access buckets directly (`save.economy.data as GameModels.EconomyData`) or add
## their own game-specific shortcut methods here.

var _dm: Node
var _data_signals: Node
var _logger: Node

func configure(data_manager: Node, data_signals: Node, logger: Node) -> void:
	_dm = data_manager
	_data_signals = data_signals
	_logger = logger

# ==============================================================================
# 📦 TYPED REPOSITORY ACCESSORS (13 Domain Buckets)
# ==============================================================================

var identity: BaseRepository:
	get: return _dm.identity_repo if _dm else null

var profile: BaseRepository:
	get: return _dm.profile_repo if _dm else null

var device: BaseRepository:
	get: return _dm.device_repo if _dm else null

var metadata: BaseRepository:
	get: return _dm.metadata_repo if _dm else null

var session: BaseRepository:
	get: return _dm.session_repo if _dm else null

var settings: BaseRepository:
	get: return _dm.settings_repo if _dm else null

var progression: BaseRepository:
	get: return _dm.progression_repo if _dm else null

var economy: BaseRepository:
	get: return _dm.economy_repo if _dm else null

var inventory: BaseRepository:
	get: return _dm.inventory_repo if _dm else null

var live_ops: BaseRepository:
	get: return _dm.live_ops_repo if _dm else null

var stats: BaseRepository:
	get: return _dm.stats_repo if _dm else null

var tutorials: BaseRepository:
	get: return _dm.tutorials_repo if _dm else null

var monetization: BaseRepository:
	get: return _dm.monetization_repo if _dm else null

var custom: BaseRepository:
	get: return _dm.custom_repo if _dm else null

# ==============================================================================
# 🎯 STRONGLY-TYPED MODEL ACCESSORS (Full IDE Autocomplete & AI Typing)
# ==============================================================================

var identity_data: GameModels.IdentityData:
	get: return identity.data as GameModels.IdentityData if identity else null

var profile_data: GameModels.ProfileData:
	get: return profile.data as GameModels.ProfileData if profile else null

var device_data: GameModels.DeviceData:
	get: return device.data as GameModels.DeviceData if device else null

var metadata_data: GameModels.MetadataData:
	get: return metadata.data as GameModels.MetadataData if metadata else null

var session_data: GameModels.SessionData:
	get: return session.data as GameModels.SessionData if session else null

var settings_data: GameModels.SettingsData:
	get: return settings.data as GameModels.SettingsData if settings else null

var progression_data: GameModels.ProgressionData:
	get: return progression.data as GameModels.ProgressionData if progression else null

var economy_data: GameModels.EconomyData:
	get: return economy.data as GameModels.EconomyData if economy else null

var inventory_data: GameModels.InventoryData:
	get: return inventory.data as GameModels.InventoryData if inventory else null

var live_ops_data: GameModels.LiveOpsData:
	get: return live_ops.data as GameModels.LiveOpsData if live_ops else null

var stats_data: GameModels.StatsData:
	get: return stats.data as GameModels.StatsData if stats else null

var tutorials_data: GameModels.TutorialsData:
	get: return tutorials.data as GameModels.TutorialsData if tutorials else null

var monetization_data: GameModels.MonetizationData:
	get: return monetization.data as GameModels.MonetizationData if monetization else null

var custom_data: GameModels.CustomData:
	get: return custom.data as GameModels.CustomData if custom else null

func _ready() -> void:
	_log_info("SaveManager initialized (backed by DataManager)")
	_connect_signals()

func _connect_signals() -> void:
	if _data_signals:
		_data_signals.login_changed.connect(_on_login_changed)

func _on_login_changed(user_id: String, is_logged_in: bool) -> void:
	if is_logged_in and not user_id.is_empty():
		if identity_data:
			if identity_data.user_id != user_id or not identity_data.signed_in:
				identity_data.user_id = user_id
				identity_data.signed_in = true
				if identity:
					identity.mark_dirty()
		_log_info("User authenticated (%s). Triggering cloud synchronization..." % user_id)
		sync_cloud()

# ==============================================================================
# 💾 PERSISTENCE & STORAGE LIFECYCLE
# ==============================================================================

## Saves all dirty repositories to local disk (user://saves/).
func save_game() -> DataResult:
	if _dm:
		var res: DataResult = _dm.save()
		if res.success:
			_log_info("SaveManager: Game saved successfully")
		else:
			_log_error("SaveManager: Save failed: " + res.error_message)
		return res
	return null

## Reloads local save files from disk into active memory caches.
func load_game() -> DataResult:
	if _dm:
		var res: DataResult = _dm.load_local_data()
		if res.success:
			_log_info("SaveManager: Game loaded successfully")
		else:
			_log_warn("SaveManager: Load result: " + res.error_message)
		return res
	return null

## Wipes all in-memory caches and clears local save files from disk.
func clear_all() -> void:
	if _dm:
		_dm.clear_local()
		_log_info("SaveManager: Cleared all local data")

## Explicitly triggers a 2-way cloud synchronization.
func sync_cloud() -> DataResult:
	if _dm:
		return await _dm.sync()
	return null

## Returns true if any in-memory repository has unsaved changes.
func has_unsaved_changes() -> bool:
	if _dm and _dm.has_method("has_unsaved_changes"):
		return _dm.has_unsaved_changes()
	return false

# ==============================================================================
# 🔒 TRANSACTION MANAGEMENT
# ==============================================================================

## Begins an atomic transaction, snapshotting in-memory state.
func begin_transaction() -> void:
	if _dm:
		_dm.begin_transaction()

## Commits the transaction and persists modified dirty buckets.
func commit_transaction() -> DataResult:
	if _dm:
		return _dm.commit_transaction()
	return null

## Rolls back all memory caches to the state captured at begin_transaction().
func rollback_transaction() -> void:
	if _dm:
		_dm.rollback_transaction()

# ==============================================================================
# 🏷️ GLOBAL METADATA / KEY-VALUE STORE
# ==============================================================================

## Sets an arbitrary value in the global synced metadata store.
func set_value(key: String, value: Variant) -> void:
	if metadata:
		metadata.mutate(func(d: GameModels.MetadataData):
			d.values[key] = value
		)

## Retrieves a value from the metadata store with a fallback default.
func get_value(key: String, default_val: Variant = null) -> Variant:
	if metadata_data and metadata_data.values.has(key):
		return metadata_data.values[key]
	return default_val

## Checks if a key exists in the metadata store.
func has(key: String) -> bool:
	return metadata_data.values.has(key) if metadata_data else false

## Deletes a key from the metadata store.
func delete_value(key: String) -> void:
	if metadata:
		metadata.mutate(func(d: GameModels.MetadataData):
			d.values.erase(key)
		)

# ==============================================================================
# 🎮 GAMEPLAY CONVENIENCE SHORTCUTS (Type-Safe & Auto-Dirty Tracking)
# ==============================================================================

## Returns current balance for the given currency (defaults to "coins").
func get_currency(currency_type: String = "coins") -> int:
	return int(economy_data.currencies.get(currency_type, 0)) if economy_data else 0

## Adds currency and automatically marks dirty.
func add_currency(currency_type: String, amount: int) -> void:
	if economy:
		economy.mutate(func(d: GameModels.EconomyData):
			d.currencies[currency_type] = int(d.currencies.get(currency_type, 0)) + amount
		)

## Attempts to deduct currency. Returns false if balance is insufficient.
func spend_currency(currency_type: String, amount: int) -> bool:
	if get_currency(currency_type) < amount:
		return false
	add_currency(currency_type, -amount)
	return true

## Primary currency shortcuts ("coins")
func get_coins() -> int:
	return get_currency("coins")

func add_coins(amount: int) -> void:
	add_currency("coins", amount)

func spend_coins(amount: int) -> bool:
	return spend_currency("coins", amount)

## Returns player's current progression level.
func get_level() -> int:
	return progression_data.current_level if progression_data else 1

## Completes a stage, saves stars, advances level and awards XP.
func complete_level(level: int, stars: int = 3, xp_reward: int = 150) -> void:
	if progression:
		progression.mutate(func(d: GameModels.ProgressionData):
			d.level_stars["stage_" + str(level)] = stars
			d.current_level = maxi(d.current_level, level + 1)
			d.unlocked_levels = maxi(d.unlocked_levels, d.current_level)
			d.xp += xp_reward
		)

# ==============================================================================
# ⚡ DIRECT PROPERTY ACCESS EXAMPLES (Without Mutate / Batch Dirty Marking)
# ==============================================================================

## Adds multiple currencies at once using direct property access on economy_data,
## avoiding lambda/closure allocations and marking the repository dirty only once.
##
## Example:
##   save.add_currencies_direct({"coins": 100, "gems": 5})
##   # Equivalent direct script usage:
##   #   save.economy_data.currencies["coins"] += 100
##   #   save.economy_data.currencies["gems"] += 5
##   #   save.economy.mark_dirty()
func add_currencies_direct(currencies: Dictionary) -> void:
	if not economy_data:
		return
	for curr in currencies:
		var amount = int(currencies[curr])
		economy_data.currencies[curr] = int(economy_data.currencies.get(curr, 0)) + amount
	if economy:
		economy.mark_dirty()

## Directly sets metadata key-value pairs without lambdas, marking dirty once.
##
## Example:
##   save.set_value_direct("tutorial_seen", true)
##   # Equivalent direct script usage:
##   #   save.metadata_data.values["tutorial_seen"] = true
##   #   save.metadata.mark_dirty()
func set_value_direct(key: String, value: Variant) -> void:
	if metadata_data:
		metadata_data.values[key] = value
		if metadata:
			metadata.mark_dirty()

## Directly updates progression state in memory without lambdas, marking dirty once.
func complete_level_direct(level: int, stars: int = 3, xp_reward: int = 150) -> void:
	if not progression_data:
		return
	progression_data.level_stars["stage_" + str(level)] = stars
	progression_data.current_level = maxi(progression_data.current_level, level + 1)
	progression_data.unlocked_levels = maxi(progression_data.unlocked_levels, progression_data.current_level)
	progression_data.xp += xp_reward
	if progression:
		progression.mark_dirty()

# ==============================================================================
# 🎮 DYNAMIC DEVELOPER SANDBOX SHORTCUTS
# ==============================================================================

## Sets an arbitrary single key or N-level nested data field in the developer sandbox.
## Automatically marks the custom repository dirty for local save and cloud sync.
##
## Supports:
##   - Flat keys:       save.set_custom_data("hero_title", "Knight")
##   - Dot-separated:   save.set_custom_data("skills.warrior.slash.level", 5)
##   - Array of keys:   save.set_custom_data(["dungeons", "shrine", "boss_killed"], true)
func set_custom_data(path: Variant, value: Variant) -> void:
	if not custom_data:
		return
		
	var keys: Array = path.split(".", false) if path is String else Array(path)
	if keys.is_empty():
		return
		
	var current: Dictionary = custom_data.data
	
	# Walk through parent levels, auto-creating dictionaries if missing
	for i in range(keys.size() - 1):
		var k = str(keys[i])
		if not current.has(k) or not (current[k] is Dictionary):
			current[k] = {}
		current = current[k]
		
	# Assign the leaf value
	var leaf_key = str(keys[-1])
	current[leaf_key] = value
	
	if custom:
		custom.mark_dirty()

## Safely reads an arbitrary single key or N-level nested value from custom_data.
## Returns default_value if any key in the path does not exist.
##
## Supports:
##   - Flat keys:       var title = save.get_custom_data("hero_title", "Novice")
##   - Dot-separated:   var lvl = save.get_custom_data("skills.warrior.slash.level", 1)
##   - Array of keys:   var cleared = save.get_custom_data(["dungeons", "shrine", "boss_killed"], false)
func get_custom_data(path: Variant, default_value: Variant = null) -> Variant:
	if not custom_data:
		return default_value
		
	var keys: Array = path.split(".", false) if path is String else Array(path)
	if keys.is_empty():
		return default_value
		
	var current: Variant = custom_data.data
	for k in keys:
		if not (current is Dictionary) or not current.has(str(k)):
			return default_value
		current = current[str(k)]
		
	return current

## Checks if an arbitrary single key or N-level nested path exists in custom_data.
func has_custom_data(path: Variant) -> bool:
	if not custom_data:
		return false
	var keys: Array = path.split(".", false) if path is String else Array(path)
	if keys.is_empty():
		return false
	var current: Variant = custom_data.data
	for k in keys:
		if not (current is Dictionary) or not current.has(str(k)):
			return false
		current = current[str(k)]
	return true

## Backward-compatible shortcut aliases
func set_custom(key: String, value: Variant) -> void:
	set_custom_data(key, value)

func get_custom(key: String, default_value: Variant = null) -> Variant:
	return get_custom_data(key, default_value)

# ==============================================================================
# 🗺️ SCOTLAND YARD MAP LEVEL PROGRESSION
# ==============================================================================

const LEVEL_ORDER: Array[String] = ["tutorial", "neighbourhood", "district", "city"]

## Returns the array of unlocked level IDs.
## New players start with ["tutorial"]. Existing players keep ["tutorial", "neighbourhood", "district", "city"].
func get_unlocked_levels() -> Array[String]:
	var saved_unlocked = get_value("levels_unlocked", null)
	if saved_unlocked is Array and not saved_unlocked.is_empty():
		var res: Array[String] = []
		for lvl in saved_unlocked:
			res.append(str(lvl))
		return res

	# Check if this is an existing player save
	var is_existing_player := false
	if has("match_mode") or has("seats") or has("detective_count") or has("games_played"):
		is_existing_player = true
	elif stats_data != null and stats_data.matches_played > 0:
		is_existing_player = true
	elif progression_data != null and progression_data.unlocked_levels > 1:
		is_existing_player = true

	var default_levels: Array[String] = []
	if is_existing_player:
		for lvl in LEVEL_ORDER:
			default_levels.append(lvl)
	else:
		default_levels.append("tutorial")

	set_value("levels_unlocked", default_levels)
	save_game()
	return default_levels

## Checks if a specific level is currently unlocked.
func is_level_unlocked(level_id: String) -> bool:
	var unlocked := get_unlocked_levels()
	return level_id in unlocked

## Unlocks the next level in progression after current_level_id.
## Returns the newly unlocked level ID, or empty string if all levels are already unlocked.
func unlock_next_level(current_level_id: String) -> String:
	var unlocked := get_unlocked_levels()
	var idx := LEVEL_ORDER.find(current_level_id)
	if idx >= 0 and idx + 1 < LEVEL_ORDER.size():
		var next_lvl := LEVEL_ORDER[idx + 1]
		if not unlocked.has(next_lvl):
			unlocked.append(next_lvl)
			set_value("levels_unlocked", unlocked)
			save_game()
			return next_lvl
	return ""

## Gets the currently selected level ID.
func get_selected_level() -> String:
	var sel = get_value("selected_level", null)
	if sel is String and not str(sel).is_empty():
		return str(sel)
	var unlocked := get_unlocked_levels()
	if unlocked.has("city"):
		return "city"
	return unlocked.back() if not unlocked.is_empty() else "tutorial"

## Sets and persists the selected level ID.
func set_selected_level(level_id: String) -> void:
	set_value("selected_level", level_id)
	save_game()

# ==============================================================================
# 🎓 TUTORIAL PROGRESSION
# ==============================================================================

## Returns true if the user has completed the tutorial.
func is_tutorial_completed() -> bool:
	var val = get_value("tutorial_completed", null)
	if val != null:
		return bool(val)
	# Check if existing player who already unlocked later levels or played matches
	var unlocked := get_unlocked_levels()
	if unlocked.size() > 1 or unlocked.has("neighbourhood") or unlocked.has("city"):
		return true
	if has("games_played") or has("match_mode"):
		return true
	return false

## Sets tutorial completion state and unlocks neighbourhood level if true.
func set_tutorial_completed(completed: bool = true) -> void:
	set_value("tutorial_completed", completed)
	if completed:
		unlock_next_level("tutorial")
	save_game()

## Gets current tutorial lesson (1 = Catch Mr. X, 2 = Escape, 0 = none/normal play).
func get_tutorial_lesson() -> int:
	return int(get_value("tutorial_lesson", 0))

## Sets current tutorial lesson.
func set_tutorial_lesson(lesson: int) -> void:
	set_value("tutorial_lesson", lesson)
	save_game()

# ==============================================================================
# 🛠️ GENERIC MUTATION HELPER
# ==============================================================================

## Executes a callable mutation on a repository and automatically marks it dirty.
func mutate_repo(repo: BaseRepository, mutate_fn: Callable) -> void:
	if not repo:
		return
	repo.mutate(mutate_fn)

# ==============================================================================
# 🔄 BACKWARD-COMPATIBLE ALIASES
# ==============================================================================

func save_local() -> void:
	save_game()

func load_local() -> void:
	load_game()

func clear() -> void:
	clear_all()

# ==============================================================================
# 🔒 PRIVATE LOGGING HELPERS
# ==============================================================================

func _log_info(msg: String) -> void:
	if _logger:
		_logger.info(msg)

func _log_warn(msg: String) -> void:
	if _logger:
		_logger.warn(msg)

func _log_error(msg: String) -> void:
	if _logger:
		_logger.error(msg)
