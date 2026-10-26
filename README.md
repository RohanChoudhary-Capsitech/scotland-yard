# Scotland Yard (Godot 4)

A Scotland Yard–style hidden-movement digital board game developed in Godot 4 (GDScript, no C#) using the project service-architecture template.

---

## Architecture Rules (Follow Strictly)

- **Source of Truth**: Read `docs/DEVELOPER_CHEATSHEET.md` and `docs/README.md` before writing code. Their specifications take precedence over prompt descriptions if any conflict arises.
- **Autoload Constraint**: `ServiceRegistry` is the **only** autoload in `project.godot`. Never add autoloads. Never use `/root/...` paths.
- **Service Resolution**:
  - Get services through `inject_services(registry) -> inject_dependencies(...)` for scene-placed nodes.
  - Call `ServiceRegistry.get_service(&"key")` only at composition boundaries (e.g. bootstrap code or level setup).
- **Controller Lifecycle**:
  - Scene-placed scripts extend `UIController` or `PlayerController` where appropriate.
  - Implement `_on_ready()` instead of `_ready()` for controller initialization logic.
  - **Golden Rule**: Always call `super.<method>()` when overriding base functions (`_ready()`, `inject_services()`, `close()`).
- **Event Bus**:
  - New events go in `game/autoloads/GameBus.gd` as signals.
  - Reuse existing signals (`game_started`, `game_over`, etc.) where they fit.
- **Core Manager Usage**:
  - **Scene changes**: via `SceneManager.go_to(path)`.
  - **Popups & Panels**: via `UIManager.push_packed(packed_scene)` with paths listed in `GameConfig.UI_PANELS`.
  - **Game state**: via `GameManager.start()`, `GameManager.game_over(reason)`, and `GameManager.reset()`.
  - **Persistence & Settings**: via `SaveManager.set_value(key, val)`, `SaveManager.get_value(key, default)`, and `SaveManager.save_game()`.
  - **Logging**: via the injected `Logger` (`_logger.info()`, `_logger.warn()`, `_logger.error()`, `_logger.debug()`).
- **Visuals Constraint (Zero Tolerance)**:
  - **No custom `_draw()`**: Visual elements must never be drawn via script draw calls.
  - **No runtime node generation**: Visual nodes must never be constructed via code (`Node.new()`, `add_child()`).
  - Every visual element must exist as a node in a `.tscn` file editable in the Godot editor.
  - Scripts only move, show/hide, recolour, or animate existing nodes.
- **Naming & Folder Map**:
  - Use **PascalCase** for file names matching template conventions (`GameState.gd`, `Board.tscn`).
  - Place files strictly in the folders listed in the cheatsheet:
    - `game/scenes/boot/` — Startup scene and bootstrap script (`Boot.tscn`, `BootScene.gd`)
    - `game/scenes/Home/` — Main menu scene (`Home.tscn`, `Home.gd`)
    - `game/scenes/gameplay/` — Core game board and gameplay scenes
    - `game/scenes/ui/mfw/` — Placeholder UI panels
    - `game/scenes/ui/hfw/` — Polished UI panels
    - `game/scripts/controllers/` — Reusable scene controllers
    - `game/scripts/features/` — Reusable runtime features & factories
    - `game/scripts/managers/` — Shared application services
    - `game/autoloads/` — Composition and support scripts (`ServiceRegistry`, `GameBus`, `GameConfig`, `GameService`, `Logger`)
    - `game/assets/` — Audio, fonts, sprites, backgrounds
    - `data/` — `map.json` and static map data
    - `tools/` — Utility scripts (e.g. `generate_map.py`)
    - `tests/` — Headless test scripts
    - `docs/` — Developer documentation and cheatsheet

---

## Game Rules & Modes

For full game rules, ticket breakdowns, reveal schedules, and victory conditions, see [docs/RULES.md](file:///c:/Users/orcas/Documents/scotland-yard/docs/RULES.md).
