# GLADIATOR FRIENDSLOP

## Quick Game Design Document — V0.1

### High Concept

A chaotic 2–4 player gladiator game where players enter an arena to fight each other, fight NPC enemies together, survive ridiculous arena events, and entertain a bloodthirsty crowd.
The game is built around simple melee combat, physical weapons, environmental interaction, betrayal, teamwork, and emergent comedy.
The game should create moments players talk about afterward.
**Example:**
Four players survive several waves together. One player loses his sword and steals another player’s spear. A lion gets released. Someone gets kicked into a spike pit. The surviving players finally defeat the boss.
Then the announcer declares:
**“THE CROWD DEMANDS A SINGLE CHAMPION.”**
The remaining players slowly turn toward each other.

---

# 1. Design Pillars

## Simple Weapons

Weapons are just weapons.
There are:

- No weapon rarities
- No random weapon stats
- No elemental effects
- No weapon levels
- No legendary variants
- No RPG modifiers
- No skill trees attached to weapons

A spear is useful because it is long.
A sword is useful because it is easy to control.
A hammer is useful because it is heavy.
A shield is useful because it physically blocks attacks.
The weapon’s physical characteristics create its strengths and weaknesses.

---

## Low Abstraction, High Interaction

The player should rarely need to read menus or compare numbers.
Instead, the player interacts directly with the world.
Weapons exist physically in the arena.
Bodies exist physically.
Objects can be picked up.
Weapons can be dropped.
Shields intercept attacks.
Thrown weapons remain where they land.
Players can steal equipment from fallen enemies.
The complexity should come from systems interacting rather than complicated rules.

---

## Friends Create the Content

The game provides situations.
The players create the comedy.
The ideal match naturally produces:

- accidental team kills
- betrayals
- heroic saves
- terrible plans
- improvised weapons
- panic
- arguments
- last-second victories
- ridiculous deaths

The game should constantly give players reasons to yell at each other.

---

## The Crowd Matters

Gladiators are not simply fighting to survive.
They are performing.
The crowd reacts dynamically to what happens in the arena.
Entertaining behavior earns **Crowd Favor**.
Favor should encourage players to take risks and fight dramatically instead of always choosing the safest strategy.

---

# 2. Camera & Perspective

### Perspective

Third-person.
The camera stays relatively close to the gladiator so combat feels physical while still allowing players to understand what is happening around them.
The player should clearly see:

- their weapon
- nearby enemies
- incoming attacks
- arena hazards
- other players doing stupid things

The game should prioritize readability over cinematic realism.

---

# 3. Player Count

Primary target:
**2–4 players**
Four players is the intended experience.
Solo play may eventually be possible with NPC allies or solo arena challenges, but multiplayer is the primary focus.

---

# 4. Core Game Loop

A normal session follows this structure:

### Barracks

Players prepare between arena rounds.
↓

### Arena Event

Players enter the arena.
↓

### Fight / Survive / Compete

Complete the current event.
↓

### Crowd Reaction

Performance determines Crowd Favor and rewards.
↓

### Survivors Return

Players return to the barracks.
↓

### Prepare for Next Event

Repeat until the run ends.

---

# 5. The Barracks

Between rounds, surviving gladiators return to an underground holding area beneath the arena.
This acts as the social downtime between fights.
Players have approximately **45–60 seconds** before the next event.
Possible activities include:

- grabbing equipment
- healing
- placing bets
- interacting with NPCs
- practicing attacks
- annoying other players
- voting on upcoming events
- looking at crowd standings
- purchasing cosmetic items
- learning what the next arena event might contain

The barracks should still allow physical interaction.
Players should be able to mess around while waiting.
Then a large horn sounds.
The arena gate opens.
Everyone goes upstairs.

---

# 6. Combat Philosophy

Combat should feel:

- physical
- readable
- slightly clumsy
- dangerous
- easy to understand
- difficult to completely master

It should NOT become a hardcore medieval combat simulator.
The objective is controlled chaos.

---

# 7. Basic Player Actions

Initial controls should remain small.
Players can:

- move
- sprint
- jump
- dodge
- attack
- block
- kick
- grab
- throw
- pick up objects
- drop equipment
- taunt

Potentially:

- shove
- tackle
- drag unconscious characters

Complex fighting-game inputs should be avoided.

---

# 8. Weapons

Weapons are physical objects found in the arena or barracks.
Initial weapon roster:

### Sword

Reliable general-purpose weapon.
Moderate reach.
Fast enough to use in close combat.

---

### Spear

Excellent reach.
Useful for keeping enemies away.
Awkward when opponents get extremely close.
Excellent throwing weapon.

---

### Axe

Shorter reach.
Heavy physical impact.
Good for aggressive combat.

---

### Hammer

Slow and cumbersome.
Large physical force.
Excellent for knocking characters around.

---

### Shield

Used primarily for defense.
Physically intercepts attacks and projectiles.
Can also:

- bash enemies
- shove players
- be thrown
- protect teammates

---

### Bow

Possible later addition.
Requires physical aiming.
Limited arrows must be recovered or collected.

---

# 9. Improvised Weapons

Many arena objects can become weapons.
Examples:

- stools
- rocks
- bottles
- torches
- buckets
- broken wood
- helmets
- bones
- pieces of arena scenery

These do not require special abilities.
If it looks like something a gladiator could pick up and hit somebody with, the player should probably be able to try.

---

# 10. Physical Equipment

Equipment exists in the world.
Players do not carry a magical inventory full of weapons.
A character may roughly carry:

- one primary weapon
- one secondary weapon or shield

Weapons can be:

- dropped
- thrown
- stolen
- lost
- knocked away
- picked up by enemies
- retrieved later

Disarming a player should create immediate chaos.

---

# 11. Damage & Health

Health should remain understandable.
Players have one clear health pool.
Different weapons naturally differ in effectiveness, but the game should avoid exposing RPG-style damage statistics.
Hits should communicate damage through:

- animation
- blood
- sound
- knockback
- character reactions
- UI health feedback

Combat should feel dangerous without players needing spreadsheets.

---

# 12. Knockdowns

Heavy attacks, collisions, traps, kicks, and environmental hazards can knock characters down.
Knocked-down characters are vulnerable but not necessarily dead.
This creates opportunities for:

- rescue
- executions
- stealing weapons
- dragging teammates
- kicking someone into a hazard
- accidentally saving enemies

---

# 13. Crowd Favor

Every gladiator has a **Crowd Favor** meter.
The crowd likes entertaining behavior.
Favor can be earned through actions such as:

- dramatic kills
- throwing weapons
- environmental kills
- successful taunts
- surviving near-death situations
- defeating powerful enemies
- catching projectiles
- fighting while disadvantaged
- knocking enemies into hazards
- saving teammates dramatically

Simply killing enemies efficiently produces some favor, but spectacular actions produce more.

---

# 14. Crowd Interaction

The crowd can physically influence matches.
Depending on what happens, spectators might throw:

- weapons
- food
- coins
- rocks
- garbage
- healing items
- random objects

A highly favored gladiator might receive useful items.
An unpopular gladiator might get pelted with trash.
This should occasionally create additional chaos rather than completely determine the outcome of fights.

---

# 15. The Emperor / Arena Master

An announcer, emperor, arena master, or similar character oversees events.
This character communicates:

- match rules
- surprise events
- crowd demands
- rule changes
- executions
- new enemies
- betrayals

This gives the game a personality and allows the rules to change during matches.
Example:
**“THE CROWD IS BORED.”**
Two lion gates open.

---

# 16. Arena Events

Each arena round has a clear objective.

## Free-for-All

Every gladiator fights.
Last player standing wins.

---

## Team Battle

Players are divided into teams.
Possible formats:

- 2v2
- players vs NPC team
- mixed player/NPC teams

---

## Survival

Players cooperate against waves of enemies.

---

## Beast Hunt

Players fight dangerous animals.
Examples:

- lions
- boars
- bulls
- possibly intentionally ridiculous animals later

---

## Champion

All players fight one extremely dangerous NPC gladiator.

---

## King of the Pit

Players must control an area while fighting.

---

## Protect the Favorite

One player is randomly declared the crowd’s favorite.
The group must keep that player alive.

---

## Execution

A heavily armored or unusually dangerous enemy enters the arena.
Players must kill them.

---

## Last Champion

Players cooperate through a PvE event.
Once the enemies are defeated, the arena master announces that only one gladiator may survive.
The match becomes PvP.

---

# 17. Arena Hazards

The arena itself should frequently become part of combat.
Potential hazards:

- spike pits
- trapdoors
- swinging logs
- collapsing platforms
- fire jets
- falling statues
- rolling objects
- animal gates
- chariots
- oil patches
- moving walls
- rotating obstacles

Hazards should interact with NPCs and players equally.
Players should be encouraged to deliberately use them against enemies.

---

# 18. Modular Arena

The initial game should NOT require many maps.
Start with one strong arena.
Different layouts and hazards can be activated between rounds.
Examples:
Round 1: Normal arena.
Round 2: Spike pit opens in center.
Round 3: Two animal gates activate.
Round 4: Platforms and swinging hazards appear.
Round 5: Arena partially collapses.
The same environment should support many different situations.

---

# 19. PvE Enemies

NPC gladiators should use the same fundamental combat rules as players.
Initial enemy types:

### Basic Gladiator

Sword and shield.

---

### Spearman

Keeps distance and attacks from range.

---

### Heavy Gladiator

Uses a large weapon and relies on heavy attacks.

---

### Champion

More aggressive and capable NPC used as a boss encounter.
Enemies should not rely on enormous health bars.
Difficulty should primarily come from:

- positioning
- numbers
- equipment
- aggression
- arena conditions

---

# 20. Animals

Animals should behave differently from humanoid enemies.
Examples:

### Lion

Fast and aggressive.
Leaps at characters.

---

### Boar

Charges directly through groups.

---

### Bull

Extremely dangerous charge attack.
Can send characters flying.
Animals create unpredictable movement and force players to react differently from normal melee opponents.

---

# 21. Death

Death should not remove the player from the game.
A dead player becomes a **spectator**.
The player’s perspective moves into the arena stands.
They can continue interacting with the match.
Possible spectator actions:

- cheer
- boo
- throw food
- throw garbage
- throw weapons
- vote on events
- spend spectator currency to trigger minor arena events

This allows dead players to become part of the chaos instead of sitting on a death screen.

---

# 22. Spectator Balance

Spectators should influence matches without completely controlling them.
Actions should have:

- cooldowns
- limited currency
- random availability
- small individual effects

The goal is interference, not domination.

---

# 23. Betrayal

Temporary cooperation should be encouraged.
Permanent alliances should not be guaranteed.
Some arena events intentionally change player relationships.
Players may go from:
**Cooperative**
to:
**Competitive**
within the same match.
The game should create moments where everyone realizes simultaneously:
**“Oh no. We have to fight each other now.”**

---

# 24. Progression

Meta progression should remain light.
Players should NOT grind for stronger characters or statistically superior weapons.
Progression can unlock:

- helmets
- armor appearances
- sandals
- capes
- scars
- tattoos
- victory poses
- taunts
- banners
- titles
- voice lines
- barracks decorations

A new player should have the same fundamental combat capability as an experienced player.
Experience should create skill and knowledge—not larger numbers.

---

# 25. Money

Players may earn coins from arena performances.
Coins can be used primarily during the current run or for cosmetics.
Potential uses:

- healing
- betting
- cosmetics
- temporary access to certain equipment
- bribing NPCs
- spectator interactions

Money should not create permanent combat advantages.

---

# 26. Betting

Before some rounds, players may gamble coins.
Examples:

- which player survives longest
- whether everyone survives
- whether a specific beast dies
- whether the upcoming champion survives

Betting creates another reason for players to behave selfishly or betray each other.

---

# 27. Tone

The world should feel brutal but ridiculous.
Not pure parody.
Not historically accurate simulation.
Think:
**violent gladiator spectacle + physical comedy + idiots trying to survive.**
The game should be capable of looking genuinely cool immediately before something extremely stupid happens.

---

# 28. Art Direction

Stylized 3D.
Characters should have exaggerated proportions.
Possible direction:

- large helmets
- chunky armor
- oversized sandals
- expressive body animation
- readable silhouettes
- exaggerated weapons
- dusty environments
- bright banners
- enormous noisy crowd

Visual imperfections can complement the physical comedy.
Realistic graphics are unnecessary.

---

# 29. Audio

Audio will be extremely important.
The arena should sound alive.
Key sounds include:

- roaring crowd
- chanting
- boos
- laughter
- metal impacts
- weapons hitting shields
- bodies hitting the ground
- gates opening
- arena horns
- animals
- announcer commentary

Proximity voice chat should be strongly considered.
Hearing someone’s voice disappear as they get launched into a pit is exactly the kind of moment the game should create.

---

# 30. Match Length

Target individual arena event:
**3–8 minutes**
Target multi-round session:
**20–40 minutes**
Rounds should move quickly.
Downtime should stay short.

---

# 31. MVP Prototype

The first playable prototype should be extremely focused.

### Environment

- 1 arena
- 1 small barracks

### Multiplayer

- 2–4 players

### Player Mechanics

- movement
- attack
- block
- kick
- grab
- throw
- pickup/drop
- health
- death
- knockdown

### Weapons

- sword
- spear
- hammer
- shield

### Enemies

- basic gladiator
- spearman
- heavy gladiator
- champion

### Arena

- spike pit
- trapdoor
- animal gate
- one moving hazard
- one environmental object

### Modes

- Free-for-All
- Co-op Survival
- Champion Fight
- Last Champion

### Systems

- Crowd Favor
- crowd reactions
- spectator mode after death
- between-round barracks
- announcer
- basic round system

This is enough to determine whether the core concept works.

---

# 32. Features We Should NOT Build Yet

Avoid during the prototype:

- huge progression systems
- crafting
- weapon stats
- weapon rarity
- procedural loot
- massive inventories
- open world
- story campaign
- dozens of arenas
- complex character classes
- skill trees
- realistic directional sword simulation
- elaborate armor statistics
- large numbers of weapons
- competitive ranked mode

These systems would increase development time without proving whether the central idea is fun.

---

# 33. Future Expansion

If the core game works, expansion becomes mostly additive.
Possible future content:

- additional arenas
- chariot battles
- naval arena events
- more animals
- more weapons
- team tournaments
- tournament brackets
- additional bosses
- arena modifiers
- custom matches
- workshop/community arenas
- additional spectator interactions
- additional crowd events
- gladiator customization
- rotating challenge modes

---

# 34. The Core Test

Every feature should be judged using one question:
**“Does this create interesting interactions between players?”**
If the answer is no, it probably does not belong in the game.
The game does not need endless content if its systems continuously create new situations.

---

# 35. Core Identity

The game is not:
**A serious gladiator simulator.**
It is not:
**An RPG with gladiator-themed loot.**
It is not:
**A wave shooter with swords.**
It is:
**A multiplayer gladiator sandbox where simple combat, physics, changing arena rules, crowd interference, cooperation, and betrayal continuously create stupid stories with your friends.**