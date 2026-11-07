# Architecture

Seeking separates logic from presentation. `game/` and `sim/` decide what happens; `view/` draws and plays it; `look/` holds the art parameters. Logic never refers to presentation, so the look can change without touching the rules.

## Start-up

`game/boot.tscn` is the main scene. It shows the loading screen, loads `game/main.tscn` on a background thread and renders a few frames behind a black cover so that shaders compile before the player sees anything. If loading stalls for three seconds it falls back to a synchronous load rather than hang.

`game/main.gd` then wires the two halves together: it creates the logic host (`game/sim_host.gd`) and the stage (`view/stage.gd`) and connects the host's signals to the stage.

## Logic: `game/` and `sim/`

- `sim/world.gd` is the simulation. The heroine is a point mass; while the hook holds she is constrained to the rope's length, so swinging, letting go and landing all fall out of the same few rules. Feel parameters are in `sim/tune.gd`, and `sim/sim_math.gd` supplies the maths functions the simulation relies on.
- The simulation steps at a fixed 120 Hz (`physics/common/physics_ticks_per_second`) and is deterministic: the same course and the same inputs always give the same run. Physics interpolation smooths the picture between ticks.
- `game/sim_gd.gd` is the interface the rest of the game uses: `load_course`, `reset`, `step`, `snapshot`. A snapshot is a flat `PackedFloat64Array`; `game/snap.gd` names its fields.
- `game/sim_host.gd` owns the run. Each physics tick it reads the one input (Space or the left mouse button held), steps the simulation and emits `stepped` with the new snapshot, plus `sim_event` for moments such as the hook biting or a landing. It also handles death and respawn at the last save point, the title screen, pause and the ending, and records which chapters have been reached in `user://progress.cfg`.
- `game/director.gd` turns the heroine's position into a mood: time of day, cloud, rain, storm, wind and gusts. It produces numbers only; the view decides what they look like.

## Content: `game/content/`

Every stretch of the course is written by hand; nothing is generated. `game/author.gd` is a small vocabulary for laying a course out section by section. `prologue.gd` and `spring.gd` are written with it, and `chapters.gd` joins them into one continuous route with a save point between chapters.

## Presentation: `view/` and `look/`

`view/stage.gd` builds the visual and audio modules and forwards the host's snapshots and events to them. Each module only reads:

| Module | Draws or plays |
| --- | --- |
| `world_view.gd` | the course: parallax hills, trunks, canopy, branches, vines, resting branches and lanterns |
| `girl_view.gd` | the heroine, a hand-painted cut-out puppet posed from the simulation |
| `camera_rig.gd` | the camera: looks ahead, pulls back with speed, shakes on impact |
| `sky.gd`, `weather.gd` | sky, sun and shadows, the sea of clouds, rain, drifting motes |
| `fauna.gd` | birds, butterflies and mist |
| `grade.gd` | the full-screen grade: a per-time-of-day colour ramp, light shafts, film grain |
| `audio_view.gd` | music per scene, ambience, birdsong, thunder and the sounds of the hook |
| `ui.gd` | the wordless interface: title, hold prompt, pause and ending |

`look/default.tres` holds the art parameters `look/look.gd` declares, and `look/kits.gd` lists the art elements each scene uses. Restyling a scene means editing these and the textures in `art/`, not the code.

Shaders are in `view/shaders/`; the project uses the Forward+ renderer with HDR 2D so that bright light can bloom.

## Assets

- `art/` holds the hand-painted textures; the scenery and the heroine have matching `_n` normal maps for 2D lighting.
- `audio/` holds the music, sound effects and ambience, all Ogg Vorbis at 48 kHz to match the mixer. `audio/amb/ambience.json` describes the ambience layers.
- Each asset's `.import` file is committed so that every machine imports it the same way.
