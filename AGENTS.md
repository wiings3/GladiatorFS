# Working on GladiatorFS

- This repository is the source of truth. Preserve the existing `main` history and work inside `gladiator-fs/`.
- Target Godot 4.5.1 with GDScript. The current prototype also runs on Godot 4.5 stable.
- Read `docs/GDD.md` for the design and `README.md` for launch instructions and current limitations.
- Weapons are ordinary physical equipment. Do not introduce rarity, random weapon rolls, levels, elemental abilities, or RPG progression.
- Keep gameplay host-authoritative. RPCs belong to the consistent `/root/Main` path. Identify remote input using the sending peer; never accept client-authoritative damage, inventory, or transforms.
- Keep network snapshots below the transport MTU using the existing compressed chunking protocol.
- Run the gameplay and combat tests after changing combat or round flow; run the camera and movement tests after changing view controls or character/camera interpolation; run the four-process network test after changing networking or replicated state. Inspect the engine output for script errors as well as exit status.
- Keep generated Godot caches, temporary captures, and exported executables out of Git. Commit `.gd.uid` files.
- Fixed weapon mass, geometry and inertia affect physical handling and carried movement speed. Keep mouse-driven contact authoritative; do not restore click-triggered damage cones for held weapons.
- Keep light weapons snappy and the camera free during attacks. Taps thrust through actual swept geometry; small wiggles cannot accumulate swing damage. Heavy weapons wind up slowly and release fast. NPC defense reacts to visible attacks with a delay and uses the same stamina limits as players.
- Art and sound are generated in code for the prototype. Keep the game runnable without external downloads or addons.
