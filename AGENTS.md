Repository Guidelines

## Project Structure & Modules
- Godot 4.4 project configured in `project.godot`; main entry scene at `scenes/main.tscn` with environment settings in `scenes/main-environment.tres`.
- Assets live under `sample/Mini Arena/Models/...` and screenshots at `screenshots/`.
- Root contains `icon.png`/`splash-screen.png` for branding and `README.md` for overview.

## Build, Run, and Development
- Open the editor: `godot4 --editor project.godot` (ensures correct project settings are loaded).
- Run the main scene: `godot4 --path .` (uses `run/main_scene` from `project.godot`).
- Export builds via the Godot editor; add export presets before producing platform binaries.

## Coding Style & Naming
- Follow Godot defaults: indentation with tabs (Godot scripts) and snake_case for nodes/signals; PascalCase for scene names; keep resource paths concise (`res://scenes/...`).
- Prefer descriptive node names matching their role (e.g., `Camera`, `WorldEnvironment`, `Sun`).
- Maintain clean transforms and environment settings in `.tres` rather than embedding per-scene overrides.

## Testing & Validation
- No automated test suite is present. Validate by running scenes in-editor and in headless mode (`godot4 --path . --quit --no-window`) to catch missing resources.
- Before sharing builds, verify lighting and materials match the baseline screenshot in `screenshots/screenshot.png`.

## Commit & Pull Request Guidelines
- Use concise commits: imperative mood, scoped messages (e.g., `Add ambient light tweak`, `Fix banner transform`).
- Include summaries of scene or asset changes; mention affected node/resource paths.
- For PRs: describe changes, attach before/after screenshots for visual tweaks, list reproduction steps for fixes, and link related issues.

## Asset & Licensing Notes
- Included 3D assets are CC0 (see `sample/Mini Arena/License.txt`); keep attributions intact when redistributing.
- Do not replace core branding files (`icon.png`, `splash-screen.png`) without providing new sources.
