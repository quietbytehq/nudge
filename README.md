# Nudge

Nudge is a 3D arcade pinball game by QuietByte, built with Godot 4.7.
Two tables so far: **Cosmic Drift** (deep space) and **Paradise Bay** (an island table
with a pier ramp through a volcano, surfboard targets and a third flipper). Four more are planned.

## Download

Get the latest build from the [Releases](../../releases) page:

- **Linux** - AppImage (any distribution), `.deb` (Debian/Ubuntu), `.tar.gz`, or the `nudge-pinball` snap
- **Windows** - zip containing `Nudge.exe`

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Flippers | Left / Right Shift (also Ctrl, Z and /) | LB / RB |
| Launch | hold and release Space | A |
| Nudge | A / D / W | D-pad |
| Camera view | C | Y |
| Graphics quality | G | |
| Reduce effects | E | |
| Pause | Esc (then Q leaves the table) | Start |

Score 100,000 or more to enter the top ten.

## Graphics

Three quality levels (High, Medium, Low). The game lowers the level by itself
if it runs below about 45 frames per second; press G to choose one yourself.

## Building from source

    godot --path .                                        # run
    godot --headless --path . -s tests/sim_test.gd        # physics tests
    godot --headless --path . --export-release "Linux" build/linux/nudge.x86_64
    packaging/build_linux.sh 0.2.0                        # tar.gz, .deb, AppImage

## Layout

- `scripts/pin_physics.gd` - custom fixed-step ball and flipper physics
- `scripts/table_layout.gd` - the layouts of both tables
- `scripts/paradise_parts.gd` - the themed 3D parts of Paradise Bay
- `tools/make_paradise_assets.py` - builds Paradise Bay's textures from the raw art
- `scripts/table_view.gd`, `scripts/parts.gd` - procedural 3D machine and parts
- `scripts/camera_rig.gd` - follow camera
- `scripts/app.gd`, `scripts/game.gd`, `scripts/hud.gd` - screens, game flow and display
- `assets/tables/<id>/` - each table's art, music and sounds

## Licence

Apache-2.0. See `LICENSE` and `NOTICE` for third-party credits.
