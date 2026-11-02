# Miner's Fury: 4-Player Online Co-op Plan

This is the plan for turning Miner's Fury into 4-player online co-op.
Read this first in any new chat about co-op.

## Decisions (locked in)

- **4 players, online, join with a code.**
- **Steam for testing, using the free test app (Spacewar, app ID 480).**
  No store page needed. Friends just need Steam open and logged in.
  Swap in the real app ID at release ($100 Steam Direct fee).
- **Also a "this PC only" mode (plain ENet on localhost)** so we can run
  2-4 game windows on one machine to test. Steam can't do that on one account.
- **Downloadable build is fine** (no browser build needed for co-op).
- **Loot is personal.** Every player gets their own drops and keeps their own save.
- **Downed players can be revived.** A teammate stands next to you for **8 seconds**.

## How it works (architecture)

**The host runs the real game. Everyone else sends inputs and sees the results.**

- The host's copy owns: enemies, their AI and targeting, damage, health,
  drops, rounds, bosses, combos and level state.
- Each player owns their own character's movement and inputs. The host checks
  hits so nobody can cheat damage.
- Clients get enemy positions, animations and health from the host and just
  display them.
- Visual-only stuff (sparks, damage numbers, screen shake, flashes) plays on
  every machine from a one-shot "this happened" message. It does not need syncing.

### Transport layer (swappable)

One small `Net` script hides how players are connected:

- `Net.host()` / `Net.join(code)` / `Net.leave()`
- Backend 1: **Steam lobbies** (GodotSteam plugin, app 480 for now).
  The lobby ID becomes the join code shown on screen. Steam friend invites also work.
- Backend 2: **local ENet** (127.0.0.1) for testing several windows on one PC.

Everything else in the game only talks to Godot's normal multiplayer API
(RPCs, MultiplayerSpawner, MultiplayerSynchronizer), so the backend can change later.

**Check first:** GodotSteam must work with Ian's custom Godot 4.7 build
(E:\Godot\MinersFury). Use the GDExtension version of GodotSteam.

## Revive rules (defaults, change if wanted)

- At 0 health you go **DOWNED** instead of dying: you lie on the ground, can't
  act, and enemies ignore you.
- A teammate standing within ~70 units revives you over **8 seconds**. A ring
  fills over your head.
- **Proposed:** the reviver can't attack while reviving. Walking away pauses
  the progress (it doesn't reset). Taking a hit doesn't cancel it.
- **Proposed:** a 30 second bleed-out. If nobody reaches you, you're out until the
  next round, or until the boss dies.
- You get up with 2 hearts and 1.5 seconds of invincibility.
- **Everyone downed = wipe.** The run ends and the death card shows for everyone.
- Solo play stays the same as now (no one to revive you = straight to the death card).

## Stages

1. **Net layer + lobby screen**
   - Title screen: HOST / JOIN (type code) / PLAY SOLO.
   - Lobby: shows the code, connected players (up to 4) and a START button for the host.
   - Host picks the map. Everyone loads it together.
2. **Players in sync**
   - Spawn one player per peer. Only you control yours, and only your camera follows you.
   - Sync position, facing, animation, attacks, dodges, blocks and parries.
   - Weapon swap, ult aim and casts show for everyone.
   - Each player has their own HUD. Others' names and health appear over their heads.
3. **Enemies run by the host**
   - Replace every "the player" lookup with "nearest living player" or "my current target".
   - Enemies and bosses spawn on the host and are replicated to clients.
   - Damage requests go to the host, and the host applies them.
4. **Effects, projectiles and combos**
   - Water balls, necro bolts, poison globs, thunderclaps, runes and toxic waves
     get spawned by the host and shown everywhere.
   - **Cross-player combos:** a Venom rune from player A plus a Storm thunderclap
     from player B = Tetrodotoxin. Credit both.
5. **Loot, rounds, trial, revive**
   - Personal loot: each drop is visible and grabbable only by its owner.
     Simplest version: when an enemy dies, every player gets their own roll.
   - Saves stay local per player (GameState stays per machine; see the gotchas).
   - Rounds, the Colosseum, the Pufferfish trial and boss bars all work co-op.
   - The downed/revive system and wipe logic.
   - Scaling: more players = more enemy HP (around +60% per extra player). Damage stays the same.
6. **Testing and polish**
   - Run 2-4 windows locally (ENet mode) for automated bot tests.
   - Then a real Steam test with friends.
   - Add lag handling only if needed (smoothing on clients).

## Gotchas found in the current code

These are single-player assumptions that must change:

- **`get_first_node_in_group("player")`** is used in: `bat.gd`, `melee_enemy.gd`,
  `necro_bolt.gd`, `puffer_ult.gd`, `water_ball.gd`, `pickup.gd`, `hub.gd`,
  `arena.gd` (and the Colosseum/trial through it), `transfer_board.gd`, `game_ui.gd`,
  `weapon_slots.gd`. Enemies need a target picker. UI needs "my local player".
- **Hit stop and slow-mo use `Engine.time_scale`**, which is global. Online, that
  would freeze everyone's game. Make hit stop local and visual only (freeze your
  sprite and camera, not the world), and skip slow-mo in co-op.
- **Pausing** (pause menu, death card, win card) uses `get_tree().paused`. That
  can't pause an online game. In co-op the menu opens without pausing.
- **GameState is static** (one inventory per machine). That's fine for personal
  loot: each machine keeps its own save. The host only tells each player what
  they got.
- **The pufferfish targets one player.** It needs a target (rotate between
  players, or pick the closest). Its follow-up slam goes to whoever got paralyzed.
- **The Colosseum and trial death cards** should only show when the whole team is down.
- **Transfer boards and scene changes**: only the host can change the map, and
  everyone follows. Others get a "waiting for host" prompt.

## Workflow notes (how this project gets edited)

- **Game project:** E:\MinersFury\miners-fury (the engine fork in E:\Godot\MinersFury is not the game).
- **Never commit `.import` or `.uid` files.**
- **Before overwriting any file, check its timestamp on the PC.** Ian edits too.
  If it's newer, pull it in and merge instead of overwriting.
- **Don't overwrite `hub.tscn`** (Ian edits it by hand). Add camp things in code in `hub.gd`.
- **No autoloads, and don't edit `project.godot`.** Shared state uses the
  `const X = preload(...)` + static vars pattern. (The Net layer may be the one
  exception that needs an autoload. Ask Ian first.)
- **Iso math:** screen y = flat y / 2. Distance checks on the floor use
  `Vector2(off.x, off.y * 2).length()`.
- **Writing style for anything Ian reads:** casual, direct, short sentences, no em dashes.
