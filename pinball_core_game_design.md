# PINBALL — Core Game Design Document
## Visual and camera direction based on the supplied reference image

**Document status:** Core concept and presentation brief  
**Target platform:** Linux PC first; architecture should remain portable to Windows  
**Engine recommendation:** Godot 4.x with Vulkan rendering  
**Scope of this document:** The core pinball experience, physical table presentation, camera, controls, audio, animation, effects, interface, and technical requirements.  
**Not covered yet:** Table themes, individual stages, table-specific layouts, missions, progression, unlocks, and campaign structure. These will be designed separately in the next planning discussion.

---

## 1. The vision

Create a premium, realistic 3D pinball simulation that looks and feels like a beautifully manufactured physical arcade machine.

The supplied reference image is the visual benchmark:

- A traditional pinball cabinet viewed from an elevated, angled camera.
- A richly illustrated playfield with physical-looking lanes, inserts, targets, posts, bumpers, ramps, and flippers.
- Chrome and brushed-metal rails, screws, brackets, and other mechanical details.
- Bright lamps and illuminated playfield elements.
- A polished steel ball whose movement is easy to read.
- Strong impact feedback: sparks, brief light flashes, and energetic ball trails when appropriate.
- A score display positioned as part of the machine.
- A sense of depth, scale, and real physical construction.

The result should not look like a flat mobile pinball game, a floating hologram, or a purely abstract sci-fi interface. It should look like a real premium arcade machine recreated in 3D.

**Core design principle:** Realistic physical pinball first; cinematic presentation and modern effects enhance it without hiding the gameplay.

## 2. Reference-image interpretation

Use the supplied image as a guide to the overall composition and material language, not as a requirement to copy every graphic or mechanism exactly.

### Visual characteristics to reproduce

1. **Table composition:** A long, sloped playfield filling most of the screen, with the lower flippers clearly visible.
2. **Physical construction:** A substantial cabinet, side rails, metal trim, posts, brackets, and believable mechanical assemblies.
3. **Playfield surface:** Printed artwork beneath transparent protective surfaces, with layered plastics and metal components.
4. **Lighting:** Bright inserts, coloured lamps, illuminated bumpers, and reflections that make the machine feel powered on.
5. **Ball readability:** The ball must remain visually distinct from the artwork, even when moving quickly.
6. **Impact feedback:** Short-lived sparks and flashes at strong impacts; trails should communicate speed rather than obscure the table.
7. **Score display:** A visible, integrated score panel with crisp, readable digits.

### Materials and rendering

- Use physically based materials (PBR).
- Give the ball a polished metal appearance with convincing highlights and reflections.
- Use separate materials for painted wood, printed artwork, rubber, plastic, glass, chrome, and brushed metal.
- Use realistic roughness variation; avoid making every surface equally glossy.
- Add subtle wear and manufacturing detail where it improves authenticity.
- Keep important playfield markings and targets readable under coloured lighting.

## 3. Camera direction — the signature feature

The camera should be dynamic. It should follow the ball intelligently while keeping enough of the playfield visible for the player to understand where the ball is going and how to react.

A camera that simply locks onto the ball would be frustrating: it could hide the flippers, targets, or the ball's destination. The system must balance **ball focus, player awareness, and table context**.

### 3.1 Default camera: intelligent ball-follow

- Begin with an elevated, three-quarter view similar to the reference image.
- Keep the table oriented consistently, with the drain and flippers toward the bottom of the screen.
- Track the ball smoothly as it travels around the playfield.
- Use velocity-aware look-ahead so the camera gently anticipates the ball's direction.
- Shift the framing only as much as needed to keep the ball and relevant play area visible.
- Keep the lower flippers and drain area visible whenever practical.
- Respect camera limits so the view never moves outside the playable table or clips through machine geometry.

### 3.2 Camera behaviour by situation

| Gameplay situation | Camera response |
|---|---|
| Ball moving in the central playfield | Hold a stable, readable view with subtle tracking |
| Ball entering an upper lane or ramp | Smoothly bias the view toward the ball's route |
| Ball moving quickly across the table | Use predictive look-ahead and slightly widen the view if needed |
| Ball approaching the flippers | Reframe to show the ball, both flippers, and the lower playfield |
| Ball entering a launcher lane | Show the launcher and the ball clearly |
| Multiball | Widen the framing to keep as many balls visible as possible |
| Major impact or jackpot | Brief, controlled cinematic emphasis, then return to gameplay framing |
| Ball drain | Follow the ball naturally, then transition to the next-ball presentation |

### 3.3 Camera motion quality

The camera must never snap or jitter during ordinary gameplay.

Implement:
- Smooth positional damping.
- Smooth rotation interpolation.
- A configurable look-ahead point based on ball velocity.
- A soft dead zone so tiny ball movements do not constantly move the camera.
- Speed-sensitive framing.
- Smooth zoom changes with conservative limits.
- Collision-aware camera placement to prevent clipping through the cabinet or playfield.
- A short settling period after dramatic camera movement.

Camera motion should feel like a skilled arcade camera operator, not like a security camera rigidly attached to the ball.

### 3.4 Camera modes

Offer these modes in Settings:

1. **Dynamic Follow (default):** Smoothly follows the ball and preserves useful table context.
2. **Full Table:** A mostly fixed elevated view for players who prefer maximum awareness.
3. **Cinematic:** More expressive camera movement for attract mode, replays, and selected celebrations. It must not interfere with normal control.
4. **Reduced Motion:** Restricts camera movement, zoom, shake, and dramatic transitions.

Allow players to adjust camera follow strength and camera sensitivity.

### 3.5 Camera rules that must not be broken

- Never let the ball disappear behind interface elements.
- Never zoom so tightly that the player cannot anticipate the next shot.
- Never rotate the table unpredictably during active play.
- Do not shake the camera continuously.
- Camera shake must be brief, optional, and reserved for significant impacts.
- During multiball, prioritise seeing all balls over close-up framing.
- The player must always have a reliable view of the flippers before the ball reaches them.

## 4. Physical pinball simulation

The ball must feel weighty, fast, and responsive. It should not move like a floating object or a simple animation following a predefined path.

### Required physics behaviour

- Gravity and table inclination.
- Ball momentum and velocity.
- Realistic collisions with rails, posts, bumpers, targets, and other balls.
- Surface friction and rolling behaviour.
- Flipper impulse and angle-dependent launches.
- Ball spin where practical.
- Controlled ball-to-ball collisions.
- Ramp and guide-rail transitions.
- Reliable drain and out-of-play detection.
- Consistent behaviour at different frame rates.

### Physics implementation notes

Use a fixed physics timestep, continuous or swept collision detection for the fast-moving ball, and sub-stepping where required. Tune collision shapes and contact response carefully.

The ball's physical simulation must be authoritative. Visual trails, sparks, camera movement, and sound must react to actual gameplay events; they must not determine the ball's position.

Flippers need special attention. Their movement, angular velocity, collision response, and impulse should produce skill-based shots rather than simply launching the ball upward.

## 5. Animation and mechanical life

The machine should feel active and responsive, even when the ball is not currently hitting something.

### Mechanical animations

- Flippers rotate with convincing mechanical timing.
- Bumpers compress or recoil when struck.
- Drop targets fall and reset.
- Stand-up targets flex or move when hit.
- Spinners rotate according to ball contact.
- Gates and diverters open and close.
- Ramps and moving mechanisms animate where the design requires them.
- The plunger or launcher moves and releases with physical timing.
- Lamps and illuminated inserts react to events.

### Ball presentation

- Subtle rolling highlights and reflections.
- A restrained speed trail when the ball moves rapidly.
- Short impact sparks at appropriate metal contacts.
- Brief glow or light pulses for special scoring events.
- A clear visual distinction between the ball and the playfield.

Effects must be event-driven and short enough that they never obscure the ball, flippers, or targets.

## 6. Lighting and visual effects

The visual target is realistic arcade hardware with polished, modern rendering.

### Lighting

- Dynamic coloured playfield lamps.
- Emissive inserts and illuminated targets.
- Realistic reflections on metal rails and the ball.
- Soft shadows from raised components.
- Controlled bloom around bright lights.
- Ambient lighting that preserves detail in darker areas.
- Reflections that do not overwhelm performance or readability.

### Effects

- Small sparks on selected metal impacts.
- Brief flashes when bumpers and targets activate.
- Particle bursts for major scoring events.
- Subtle ball trails at high speed.
- Controlled screen-space effects for special moments.
- Optional, restrained camera shake on heavy impacts.

Avoid constant explosions, excessive bloom, or oversized neon effects. The physical machine must remain the star.

## 7. Sound design and music

Audio is a core part of the game, not an afterthought. Every important physical interaction should have a satisfying sound.

### Mechanical and gameplay sounds

- Ball rolling over the playfield.
- Ball striking metal rails and posts.
- Rubber and plastic collisions.
- Flipper activation and release.
- Distinct bumper sounds.
- Target hits and drop-target resets.
- Spinner rotation.
- Ball entering ramps and lanes.
- Plunger pull and launch.
- Drain and end-of-ball sounds.
- Score, bonus, and jackpot feedback.

Use varied sound samples and subtle pitch or volume variation so repeated hits do not sound identical.

### Music

Create an original, energetic arcade soundtrack. Music should support the game rather than compete with its mechanical sounds.

Use adaptive music layers:
- A main gameplay music bed.
- Additional rhythmic or melodic layers for heightened action.
- A stronger musical accent for major scoring events.
- A brief celebratory sting for a jackpot or record.
- Calm menu and attract-mode music.

Music transitions should be smooth. Avoid abrupt volume jumps.

### Spatial audio and mixing

- Position impact sounds in relation to the ball and machine.
- Use stereo or positional cues to help players understand where contact occurred.
- Keep flippers, ball collisions, and important gameplay cues clear in the mix.
- Provide separate volume controls for music, effects, and interface sounds.
- Include mute controls and sensible default levels.
- Support headphones and ordinary stereo speakers.

All music and sound assets must be original, properly licensed, or otherwise cleared for distribution.

## 8. User interface and on-screen information

The interface should look like part of a premium arcade machine, while keeping the playfield unobstructed.

Display only essential information during active play:
- Current score.
- Best score.
- Player number, if applicable.
- Ball number.
- Multiplier or bonus status when relevant.
- Short, readable feedback for major scoring events.

Use the machine's physical score display where appropriate, with a clean optional digital overlay for accessibility and readability.

Menus should include:
- Start game.
- Controls and help.
- Camera settings.
- Graphics settings.
- Audio settings.
- Accessibility settings.
- Exit.

Do not place large permanent panels over the playfield.

## 9. Controls

Provide keyboard and controller support from the beginning.

### Suggested keyboard defaults

| Action | Key |
|---|---|
| Left flipper | Left Ctrl or Left Shift |
| Right flipper | Right Ctrl or Right Shift |
| Launch / plunger | Space |
| Nudge left | A |
| Nudge right | D |
| Nudge forward | W |
| Pause | Esc |

### Controller

- Map left and right flippers to comfortable shoulder buttons or triggers.
- Map launch to a face button.
- Provide configurable nudge controls.
- Support controller remapping.
- Use vibration only for meaningful impacts, with an intensity setting.

All controls must be remappable. Include an on-screen control guide.

## 10. Accessibility and comfort

- Adjustable camera follow strength.
- Full-table and reduced-motion camera options.
- Adjustable camera shake.
- Independent music and sound-effect volumes.
- Remappable keyboard and controller inputs.
- Clear high-contrast score text.
- Optional reduced visual effects.
- Adjustable graphics quality.
- Pause at any time.

The game should remain playable with visual effects reduced or disabled.

## 11. Technical direction

### Recommended stack

- **Engine:** Godot 4.x.
- **Rendering:** Vulkan renderer, with a compatibility path if required by supported hardware.
- **Scripting:** GDScript for gameplay and presentation; use native extensions only if profiling proves they are necessary.
- **3D assets:** Blender.
- **Audio:** Godot audio buses and event-driven sound management.
- **Physics:** A carefully tuned fixed-step simulation, with custom handling for fast ball and flipper interactions where the built-in physics system is insufficient.

### Linux-first requirements

- Build and test on a current 64-bit Linux environment.
- Provide a standalone Linux build.
- Support keyboard and common game controllers.
- Offer graphics presets and resolution selection.
- Save settings and local high scores reliably.
- Keep assets and configuration paths compatible with Linux conventions.
- Test on both integrated and discrete GPUs where available.

### Performance targets

- Aim for stable 60 FPS as the baseline.
- Support higher refresh rates where hardware permits.
- Keep physics behaviour consistent regardless of rendering frame rate.
- Provide scalable shadows, reflections, particles, and post-processing.
- Avoid visual effects that cause sudden performance drops during multiball.

## 12. Gameplay camera and effects acceptance checklist

The core presentation is not complete until these checks pass:

- [ ] The default view resembles the elevated, angled physical-table view in the reference.
- [ ] The camera follows the ball smoothly without snapping.
- [ ] The camera anticipates ball movement without moving too far ahead.
- [ ] The ball, flippers, and relevant playfield remain visible during normal shots.
- [ ] The camera reframes toward the lower playfield as the ball approaches the flippers.
- [ ] The camera widens appropriately during multiball.
- [ ] The camera does not clip through the cabinet or table.
- [ ] Full Table and Reduced Motion modes work correctly.
- [ ] Ball trails and sparks enhance speed and impact without hiding gameplay.
- [ ] Mechanical animations respond to actual collisions.
- [ ] Gameplay sounds respond to actual physical events.
- [ ] Music transitions smoothly between gameplay intensity levels.
- [ ] Music, effects, and interface volumes can be adjusted independently.
- [ ] Controls can be remapped.
- [ ] The game maintains stable performance on the agreed target hardware.

## 13. Deliberately deferred for the next discussion

The following decisions are intentionally open. They should not be invented or locked down in this core document:

- Number and identity of pinball tables.
- Visual themes for individual tables.
- The physical layout and unique mechanisms of each table.
- Stages, levels, and progression.
- Table-specific missions and objectives.
- Bosses, special events, and unlock systems.
- Tournament and multiplayer structure.
- Additional content and release roadmap.

These will be designed after the core camera, physics, visual style, sound, and controls have been agreed.

---

## Final creative direction

**Make it feel like a real, beautifully engineered arcade pinball machine — then give it the camera intelligence, lighting, animation, sound, and polish of a modern premium PC game.**

The ball is the star. The camera follows it intelligently. The machine reacts physically. Every hit sounds satisfying. Every major moment feels exciting. And the player never loses control or awareness of the table.
