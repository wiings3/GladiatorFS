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
| WASD / mouse | Move / aim the character and camera |
| Shift / Space | Sprint / jump |
| Ctrl | Short dodge with a cooldown |
| Left mouse, held + mouse drag | Steer the weapon: pull sideways to slash, pull down for an overhead |
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

While left click is held, the mouse steers your weapon and the camera stays steady. Release it to look around normally. Pull the weapon to one side to wind up, then sweep through an opponent. Horizontal drags level the swing; vertical drags bring it across the front of the body. Diagonal drags retain both axes. You can hold right click at the same time to keep your shield raised at your current aim; release left click to redirect the camera and shield. **Esc → Swing Sensitivity** adjusts the hand independently of camera sensitivity.

The weapon must actually cross a body with enough motion to hurt it. A stationary blade does not drain health, and a single contact cannot deal damage every physics tick. Walls, shields, bodies, and loose equipment interrupt the arc. The hand follows a spring/inertia simulation: the hammer accelerates more slowly, carries more momentum, and moves the player more slowly than the sword. The spear's longer shaft also resists quick changes of direction; its tip is the damaging part. Carried shields contribute to movement weight, too. These are fixed physical properties, with no random rolls or upgrade system.

The menu does **not** pause a running arena. Heavy hits and kicks can disarm you. Retrieve the dropped equipment or improvise. Sparring in the barracks is nonlethal.

## Included in this prototype

- **Third-person combat:** movement, sprinting, jumping, dodging, mouse-driven weapon arcs, aimed physical shields, kicks, knockdowns, health, death, and body dragging.
- **Physical equipment:** sword, spear, hammer, shield, and throwable clay jars. Dropped and thrown equipment uses rigid-body physics and remains recoverable. No rarity, random rolls, upgrades, weapon levels, or special abilities. Reach, mass, inertia, and impact distinguish the weapon shapes and affect handling and movement.
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
godot --headless --path gladiator-fs --script res://tests/movement_test.gd
python gladiator-fs/tests/run_network_test.py godot
```

The gameplay suite checks movement, nonlethal barracks combat, kicks/disarming, dodging, throws and recovery, pickups, death/spectating, hazard activation, all four event flows, and cleanup. The combat suite checks lateral and overhead contact, shield direction/tilt, wall obstruction, misses, stationary blades, spear reach, inertia, carried weight, and mouse controls. The movement test stresses strafe tracking at 30 physics ticks and 144 rendered frames per second. Character visuals and the camera now share the same interpolated transform; the previous separate camera filter caused the visible wobble. The multiplayer suite launches **four separate Godot processes** and checks joining, remote movement, mouse-driven hand motion, shield aim and throwing, world replication, the PvP transition, death, spectator interaction, client disconnect, and host disconnect. The development pass also rendered and inspected the menu, barracks, arena, pit, weapon/shield poses, and settings UI at 1280 × 800.

Networking keeps simulation on the host. Clients send bounded input for their own peer ID; the host resolves damage, pickups, drops, AI, and hazards. Full state snapshots are compressed and divided into payloads smaller than an ENet datagram; incomplete or stale snapshots are discarded. Reliable actions and announcements use a separate channel from input and state.
