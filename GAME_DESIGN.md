Here’s a ready-to-paste **progressive prompt** you can give to Codex to help you build a procedural maze in **Godot (GDScript)** based on our design.

---

**PROMPT FOR CODEX:**

You are an expert Godot 4 + GDScript assistant.
We are building a **2D top-down maze game** in Godot, and I want you to help me progressively implement the **maze generator** and connect it into a simple playable scene.

Follow these rules throughout:

* Always target **Godot 4** and **GDScript**.
* Assume a **2D top-down** game with a **TileMap**-based maze.
* Explain briefly what you are doing, then provide clean, well-formatted code blocks.
* At each step, if something is ambiguous, **make a reasonable choice and state it** instead of asking me questions.
* Avoid unnecessary boilerplate comments.

---

### Game & Maze Requirements

Use these design constraints while generating code:

* **Genre:** Puzzle / Maze / Exploration
* **Perspective:** Top-down 2D
* **Core loop:** Player starts at maze entrance, navigates to exit through a maze, possibly collecting items later (not needed in the first version).
* **Maze type:** Grid-based, procedurally generated.
* **Difficulty:** Configurable by changing maze width/height and possibly adding dead ends / longer paths.
* **Maze structure:**

  * Use an internal grid (e.g., `width x height` cells).
  * Generate a **perfect maze** (one unique path between any two cells) using a standard algorithm such as **recursive backtracker** or **depth-first search**.
  * Expose maze parameters: `width`, `height`, `cell_size`, `seed` (optional).
  * Have **one entrance** and **one exit** (e.g., left side → right side or top → bottom).
* **Engine specifics:**

  * Use a `TileMap` node for walls and floor.
  * Use two tile IDs or layers: one for **floor/path**, one for **walls**.
  * The maze generator should be encapsulated in a single script that I can attach to a node (e.g., `MazeGenerator.gd` on a `Node2D` or `TileMap`).

Later, I might add:

* Timers, collectibles, power-ups, enemies, etc., but **for now focus solely on maze generation and basic visualization**.

---

### Progressive Task Plan

Work in **stages**. In each stage, provide the full code needed for that stage, and state clearly which node the script should be attached to.

#### Step 1 – Minimal Scene & Node Setup

1. Define the recommended **scene structure** in Godot 4 for a simple maze prototype, for example:

   * `Main` (Node2D)

	 * `MazeTileMap` (TileMap)
	 * `Player` (CharacterBody2D, to be added later)
2. Provide a simple `Main.tscn` description (in text form) and a script `Main.gd` if needed.
3. Make sure the scene can run empty (no maze yet) without errors.

#### Step 2 – Basic Maze Data Structure (No Rendering Yet)

1. Create a script `MazeGenerator.gd` that:

   * Stores `width`, `height`, and an internal 2D array representation of the maze.
   * Represents cells as either **walls** or **paths** in a way that is easy to render on a TileMap.
2. Implement the **maze generation algorithm** (use recursive backtracker / DFS or another standard algorithm).

   * The algorithm should generate a perfect maze.
   * Have a function like `generate_maze(width: int, height: int) -> void`.
3. Add a function `get_maze_data()` that returns the final grid (for debugging / rendering).

#### Step 3 – Rendering the Maze with TileMap

1. Assume I have a `TileMap` named `MazeTileMap` in `Main.tscn`.
2. Show how to:

   * Assign the `MazeGenerator` to the scene (instantiate it or make it a script on `MazeTileMap`).
   * Use the generated grid to call `set_cell` / `set_cellv` in Godot 4’s TileMap API.
   * Use tile IDs such as:

	 * `0` for floor/path
	 * `1` for wall
3. Provide a script (for example attached to `MazeTileMap`) that:

   * On `_ready()` calls the maze generator.
   * Fills the TileMap according to the maze.
   * Clearly defines where entrance and exit are located (e.g., left and right edges).

#### Step 4 – Configurable Parameters & Regeneration

1. Expose export variables to Godot’s inspector, e.g.:

   ```gdscript
   @export var maze_width: int = 21
   @export var maze_height: int = 21
   ```
2. Add a method `regenerate_maze()` that:

   * Clears the TileMap.
   * Generates a new maze with the current parameters.
   * Re-renders it.
3. Optionally add a simple key input (e.g., press `R`) in `Main.gd` or `MazeTileMap.gd` to regenerate the maze at runtime.

#### Step 5 – Player Spawn (Basic)

1. Show how to:

   * Place a simple `Player` (CharacterBody2D) at the maze entrance.
   * Optionally add basic movement using arrow/WASD keys.
2. Ensure the player starts on a walkable tile and collides properly with wall tiles using a `CollisionShape2D` / tile collision.

---

### Output Style Guidelines

At each step:

* Start with a brief explanation (2–5 sentences max).
* Then provide the relevant GDScript code in fenced code blocks, specifying which node each script attaches to.
* Make sure the code is consistent across steps (names of nodes, scripts, variables).

Now, begin with **Step 1 – Minimal Scene & Node Setup**.
