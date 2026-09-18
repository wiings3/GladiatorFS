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
| Left mouse | Attack |
| Right mouse, held | Block; a shield intercepts frontal strikes and throws |
| F | Kick; knock someone down or into a hazard |
| E | Pick up or swap nearby equipment; eat bread |
| Q | Drop primary equipment |
| R | Throw primary equipment in the camera's aim direction |
| V | Throw the shield |
| G | Grab/release a nearby knocked-down character or corpse |
| T | Taunt for Crowd Favor; worth more near danger |
| Enter | Host: open the gate from the barracks |
| 1 / 2 / 3 / 4 | Host: select the next event in the barracks |
| Esc | Mouse sensitivity, volume, resume, or leave session |
| Left / right arrows, when dead | Switch spectator target |
| E / R, when dead | Cheer / throw a tomato toward the selected gladiator; six-second cooldown |

The menu does **not** pause a running arena. Heavy hits and kicks can disarm you. Retrieve the dropped equipment or improvise. Sparring in the barracks is nonlethal.

## Included in this prototype

- **Third-person combat:** movement, sprinting, jumping, dodging, attack windups, directional blocking, kicks, knockdowns, health, death, and body dragging.
- **Physical equipment:** sword, spear, hammer, shield, and throwable clay jars. Dropped and thrown equipment uses rigid-body physics and remains recoverable. No rarity, random rolls, upgrades, weapon levels, or special abilities. Reach, attack motion, and impact distinguish the weapon shapes.
- **One arena and barracks:** a central trapdoor over spikes, a rotating beam, an animal gate, equipment on the floor, and between-round recovery.
- **Four enemy archetypes:** sword/shield guard, spearman, heavy, and the champion. A charging boar can interrupt a long event.
- **Four event modes:** Free-for-All, three-wave Co-op Survival, Champion Fight, and Last Champion. Solo FFA supplies three opponents. Last Champion moves from guards to a champion, then to PvP if multiple players survive; a sole survivor wins immediately.
- **Crowd systems:** per-player favor, taunts, favor for spectacle, bread/tomato drops, synthesized reactions, and on-screen announcer calls.
- **Death stays social:** spectators can switch targets, cheer, and throw tomatoes. Everyone returns for the next event.
- **Round flow:** initial barracks waits for the host; six seconds to enter the arena; events last up to three minutes; results display for eight seconds; subsequent barracks phases last 45 seconds or can be skipped by the host.
- **Multiplayer:** host plus three clients over ENet. Friendly fire is on, including during co-op.

## Prototype boundaries

This is a systems prototype with original geometric art, procedural animation, and synthesized placeholder audio. Knockdowns use controlled poses rather than a full active-ragdoll skeleton. Melee uses reach/cone and obstruction checks; shields use finite interception planes. Loose equipment is physically simulated by the host. The announcer is text with audio cues, not recorded speech.

Clients interpolate host snapshots. There is no client movement prediction or lag compensation yet, so internet latency will be noticeable. AI uses simple local steering and pit avoidance rather than a navigation mesh. Combat timing, camera feel, NPC behavior, and difficulty need hands-on playtesting with friends. There is no proximity voice, persistence, cosmetics, betting, inventory, or meta progression yet.

## Project structure

| File | Responsibility |
| --- | --- |
| `gladiator-fs/scenes/main.tscn` | Entry point |
| `scripts/game.gd` | Session, host simulation, RPCs, round flow, AI, combat resolution, camera |
| `scripts/gladiator.gd` | Character movement, actions, health, knockdown poses, equipment display |
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
python gladiator-fs/tests/run_network_test.py godot
```

The gameplay suite checks movement, nonlethal barracks combat, shield direction, reach, kicks/disarming, dodging, throws and recovery, pickups, death/spectating, hazard activation, all four event flows, and cleanup. The multiplayer suite launches **four separate Godot processes** and checks joining, remote movement and throwing, world replication, the PvP transition, death, spectator interaction, client disconnect, and host disconnect. The development pass also rendered and inspected the menu, barracks, arena, pit, and settings UI at 1280 × 800.

Networking keeps simulation on the host. Clients send bounded input for their own peer ID; the host resolves damage, pickups, drops, AI, and hazards. Full state snapshots are compressed and divided into payloads smaller than an ENet datagram; incomplete or stale snapshots are discarded. Reliable actions and announcements use a separate channel from input and state.
