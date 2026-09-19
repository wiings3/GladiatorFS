# GladiatorFS

A playable Godot prototype of the gladiator friendslop GDD: get into trouble together, improvise with physical equipment, entertain the crowd, and sometimes turn on each other.

## Play locally

1. Pull **main** in GitHub Desktop (Fetch origin → Pull origin).
2. Import **`gladiator-fs/project.godot`** into **Godot 4.5.1** (standard GDScript version; .NET is unnecessary).
3. Press **F5**. Choose an event, then **Solo Practice** or **Host**.
4. You start with a sword and shield in the barracks. Try the other equipment on the floor. Press **Enter** to open the gates.

No addons, downloaded assets, or external services are required. The Compatibility renderer is selected. The arena and characters are built from original meshes at runtime, so the main scene's editor view is deliberately sparse; **F5** builds and runs the game.

## Playing with friends

- One player chooses **Host**. Up to three others enter the host's IP and choose **Join Friend**.
- For two instances on the same computer, join **127.0.0.1**. You can run additional instances from Godot's **Debug → Customize Run Instances** or start the project from another terminal.
- For LAN play, use the host's LAN IPv4 address (shown by `ipconfig` on Windows). Allow Godot through the host's firewall on the network being used.
- Internet direct-IP connections require a reachable host and **UDP port 27840** forwarded to that host. Some connections, including carrier-grade NAT, prevent this setup. Steam invites, matchmaking, relay servers, and automatic port forwarding are not part of this prototype.
- The host selects the event and opens the gate. A player joining during a round spectates until the next barracks phase. If the host leaves, clients return to the menu.

Godot's [hosting documentation](https://docs.godotengine.org/en/4.5/tutorials/networking/high_level_multiplayer.html#hosting-considerations) explains LAN addresses and UDP forwarding.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / aim the camera and steer your held weapon |
| C | Switch between first person and third person |
| Scroll wheel, in third person | Up: zoom closer; down: zoom farther away |
| Shift / Space | Sprint / jump |
| Ctrl | Short dodge with a cooldown |
| Left mouse | Thrust/stab in your aim direction |
| Right mouse, held + mouse aim | Raise and aim the physical shield, including up/down |
| F | Kick; knock someone down or into a hazard |
| E | Pick up or swap nearby equipment; eat bread |
| Q | Drop primary equipment |
| R | Throw primary equipment in the camera's aim direction |
| V | Throw the shield |
| G | Grab/release a nearby knocked-down character or corpse |
| T | Taunt for Crowd Favor; worth more near danger |
| Enter | Host: open the gate from the barracks |
| 1 / 2 / 3 / 4 | Host: select the next event in the barracks |
| Esc | Camera/swing sensitivity, volume, resume, or leave session |
| Left / right arrows, when dead | Switch spectator target |
| E / R, when dead | Cheer / throw a tomato toward the selected gladiator; six-second cooldown |

The game starts in first person. Press **C** to switch to third person or back at any time while alive. The scroll wheel smoothly changes third-person distance, with limits and wall collision; returning from first person restores your chosen distance. First person shows your actual hands, weapon, shield, and legs; your own head and torso are hidden locally to keep the view clear. Knockdowns briefly use third person for readability, then restore your selected view; death uses the spectator camera. The selected perspective survives round resets.

Your held weapon always follows mouse movement; no attack button is needed to swing it. Horizontal movement levels the swing, vertical movement brings it across the front of the body, and diagonal movement retains both axes while the camera remains free. Left click performs one forward stab, whether clicked or held, with a short recovery before the next one. You can hold right click at the same time to keep aiming your shield. **Esc → Swing Sensitivity** adjusts weapon response independently of camera sensitivity.

Damage requires a committed stroke or the forward part of a stab. Holding a blade against someone, walking into them, or repeatedly wiggling it a little cannot chip away health or stamina. A real swing spends stamina once when it becomes dangerous. Contact with a body, shield, object, or wall spends the stroke, kicks the weapon backward, and requires it to return through a short ready arc before it can hurt something again. Missed committed swings also need to re-arm, so frantic reversals cannot skip recovery.

Faster swings still hurt more, but health damage reaches a per-weapon ceiling. Speed beyond that ceiling becomes additional knockback, knockdowns, and disarming force instead of an instant kill. Unprotected head hits deal much more damage than torso hits, while leg hits deal less. Every gladiator's helmet softens one major head hit to 12 damage and then physically flies off; retrieve it with **E** to put it back on, or pick up someone else's helmet as a ridiculous short-range weapon.

Swords and spears respond quickly, and ordinary equipment has only a small movement penalty. The hammer winds back for roughly 0.4 seconds, then swings/falls fast before recovering. It needs a fresh gesture for another swing. Its mass makes it much better at knocking people around, and carrying it slows movement. The spear's tip is its damaging part. These are fixed physical properties, with no random rolls or upgrade system.

The **stamina bar** fuels committed swings, stabs, sprinting, dodging, blocking, and kicks. Small aim corrections are free. A sword swing costs 11 stamina, a spear swing 14, and a hammer swing 24; stabs cost less. Sprinting drains stamina only while moving, keeping a shield raised drains it slowly, and blocked impacts spend larger chunks. An exhausted guard drops, and exhausted weapon gestures cannot become damaging attacks until stamina recovers. NPCs obey the same limits and still react only to committed visible attacks rather than idle weapon movement.

The menu does **not** pause a running arena. Heavy hits and kicks can disarm you. Retrieve the dropped equipment or improvise. Sparring in the barracks is nonlethal.

## Included in this prototype

- **First- and third-person combat:** first-person default, switchable perspective, third-person wheel zoom, always-on mouse-driven weapon arcs, click-to-stab, aimed physical shields, forward kicks, stamina, hit-location damage, knockdowns, health, death, and body dragging.
- **Physical equipment:** sword, spear, hammer, shield, throwable clay jars, and helmets that pop off under major head impacts. Dropped and thrown equipment uses rigid-body physics and remains recoverable. No rarity, random rolls, upgrades, weapon levels, or special abilities. Reach, mass, inertia, impact, stamina cost, and recovery distinguish the fixed weapon shapes.
- **One arena and barracks:** a central trapdoor over spikes, a rotating beam, an animal gate, equipment on the floor, and between-round recovery.
- **Four enemy archetypes:** sword/shield guard, spearman, heavy, and the champion. A charging boar can interrupt a long event.
- **Four event modes:** Free-for-All, three-wave Co-op Survival, Champion Fight, and Last Champion. Solo FFA supplies three opponents. Last Champion moves from guards to a champion, then to PvP if multiple players survive; a sole survivor wins immediately.
- **Crowd systems:** per-player favor, taunts, favor for spectacle, bread/tomato drops, synthesized reactions, and on-screen announcer calls.
- **Death stays social:** spectators can switch targets, cheer, and throw tomatoes. Everyone returns for the next event.
- **Round flow:** initial barracks waits for the host; six seconds to enter the arena; events last up to three minutes; results display for eight seconds; subsequent barracks phases last 45 seconds or can be skipped by the host.
- **Multiplayer:** host plus three clients over ENet. Friendly fire is on, including during co-op.

## Prototype boundaries

This is a systems prototype with original geometric art, procedural animation, and synthesized placeholder audio. Knockdowns use controlled poses rather than a full active-ragdoll skeleton. Held melee uses angular spring dynamics and swept collision shapes along the visible blade, spear shaft/tip, or hammer head. Raised shields have matching physical collision shapes that follow vertical and horizontal aim. Kicks retain a short reach/cone query. Held weapons use controlled hand motion rather than unconstrained rigid-body joints. Loose equipment is physically simulated by the host. The announcer is text with audio cues, not recorded speech.

Clients interpolate host snapshots. There is no client movement prediction or lag compensation yet, so internet latency will be noticeable. AI uses simple local steering and pit avoidance rather than a navigation mesh. Combat timing, camera feel, NPC behavior, and difficulty need hands-on playtesting with friends. There is no proximity voice, persistence, cosmetics, betting, inventory, or meta progression yet.

## Project structure

| File | Responsibility |
| --- | --- |
| `gladiator-fs/scenes/main.tscn` | Entry point |
| `scripts/game.gd` | Session, host simulation, RPCs, round flow, AI, combat resolution, camera |
| `scripts/gladiator.gd` | Character movement, actions, health, knockdown poses, equipment display |
| `scripts/melee_physics.gd` | Weapon dimensions/mass, hand inertia, shared swept collision queries |
| `scripts/equipment.gd` | Loose equipment, physics, projectile sweeps, replica smoothing |
| `scripts/arena.gd` | Environment, lighting, gates, trapdoor, moving hazard |
| `scripts/visuals.gd` | Original mesh and material kit |
| `scripts/interface.gd` | Menu, HUD, settings, announcer text |
| `scripts/arena_audio.gd` | Synthesized sound cues |
| `docs/GDD.md` | Supplied design document, preserved as the design reference |

All script paths in the table are relative to `gladiator-fs/`.

## Verification

Verified with **Godot 4.5 stable** in this development environment; intended for the existing Godot 4.5/4.5.1 project. No Windows export or live internet session has been tested here.

Run from the repository root, substituting your Godot executable:

```sh
godot --headless --path gladiator-fs --editor --import --quit
godot --headless --path gladiator-fs --script res://tests/gameplay_test.gd
godot --headless --path gladiator-fs --script res://tests/combat_test.gd
godot --headless --path gladiator-fs --script res://tests/camera_test.gd
godot --headless --path gladiator-fs --script res://tests/movement_test.gd
python gladiator-fs/tests/run_network_test.py godot
```

The camera suite verifies view switching, zoom limits/smoothing, wall collision, local-only head hiding, input during attacks/menus, knockdown recovery, spectating, and respawning. The movement regression covers first person and three third-person zoom distances.

The gameplay suite checks movement, nonlethal barracks combat, kicks/disarming, dodging, throws and recovery, pickups, death/spectating, hazard activation, all four event flows, and cleanup. The combat suite checks lateral and overhead contact, shields, walls, misses, wiggle prevention, swing/stab stamina, recoil and re-arming, soft-capped damage, excess knockback, helmet protection/recovery, spear reach, hit location, physical stabs, heavy windup/release, NPC reaction windows, forward kicks, stamina recovery, carried weight, and free camera controls. The movement test stresses strafe tracking at 30 physics ticks and 144 rendered frames per second. Character visuals and the camera share the same interpolated transform to prevent strafing wobble. The multiplayer suite launches **four separate Godot processes** and checks joining, remote movement, weapon motion, shield aim, stabs, stamina and helmet replication, throwing, world replication, the PvP transition, death, spectator interaction, and disconnects. The development pass also rendered and inspected the menu, barracks, arena, pit, weapon/shield/kick/thrust poses, stamina HUD, and settings UI at 1280 × 800.

Networking keeps simulation on the host. Clients send bounded input for their own peer ID; the host resolves damage, pickups, drops, AI, and hazards. Full state snapshots are compressed and divided into payloads smaller than an ENet datagram; incomplete or stale snapshots are discarded. Reliable actions and announcements use a separate channel from input and state.
