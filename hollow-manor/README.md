# Hollow Manor

A story-driven Roblox horror game with a twist: **you are the villain.**

You wake up in your family's old manor with no memory of how you got there.
Your wife and kids are missing and something made of shadow is hunting you
through the halls. Find the five notes that explain what happened...
then look in the mirror.

Built entirely in code with [Rojo](https://rojo.space), so there's nothing to set up in Studio.
It plays solo or co-op (1–4 players recommended).

## The three acts

**Act 1: Explore.** Pitch-black manor, first-person camera. Search the library, study,
nursery, kitchen and master bedroom for the five notes. The thing patrols the house:
- It **sees** you in a cone in front of it, and from farther away if your **flashlight** is on.
- It **hears** you sprinting through walls.
- **Hide** in wardrobes. If it watched you climb in, it will drag you out.
- Lamps flicker violently when it's close, the screen darkens and your heart pounds.
- If it catches you: jumpscare, then you wake up back in the entrance hall.

**Act 2: Reveal.** Finding every note unchains the mirror room. Walk up to the glass:
your reflection copies you... until it doesn't. The notes were in your handwriting.
The thing was never chasing you. It was following you, like a reflection does.

**Act 3: Hunt.** You *become* the thing: taller, a black silhouette with red eyes, faster,
and able to see in the dark. A five-person search party arrives with flashlights.
They search the rooms, and if they spot you they **run for the police car**.
- Get close to take them.
- **Q: Hunter Sense** shows every survivor through the walls for a few seconds.
- You have 5 minutes.

**Endings** (depends on how many escape):
- 0 escape: *A Full House*
- 1–2 escape: *The Legend of Hollow Manor*
- 3+ escape: *They'll Be Back*

Then press "Wake up again" to replay.

## Controls

| Key | Act 1 | Act 3 |
|---|---|---|
| WASD | move | move |
| Shift | run (limited stamina) | stalk faster |
| F | flashlight | – |
| E | read notes / hide / open | – |
| Q | – | Hunter Sense |

Mobile players get on-screen buttons automatically.

## Running it

From this folder:

```
rojo build -o HollowManor.rbxl     # then open it in Roblox Studio and press Play
# or
rojo serve                         # live-sync into an open Studio place
```

The server builds the whole map when it starts and removes the template's `Baseplate`
and `SpawnLocation`.

**Recommended in Studio:** *Lighting → Technology = Future* for proper shadows from
flashlights and lamps.

## Sound

Roblox audio has to come from the Creator Store, so the game only uses sounds that ship
with every client (glass break, swoosh, click, a thud used as a heartbeat). For the full
experience, paste audio ids into `Config.Sounds` in `src/shared/Config.luau`:
`Ambience` (looping drone), `Chase` (looping chase music) and `Scream`.

## Changing things

Everything is in `src/shared/`:
- `Config.luau`: the ASCII floor plan (redraw the house!), speeds, stalker senses,
  hunt timer, search party names and colours, sounds.
- `Story.luau`: every line of text, including the notes, the reveal and the endings.

## Code layout

```
src/
  shared/
    Config.luau        tuning + floor plan
    Story.luau         all story text
  server/
    init.server.luau   game director: acts, notes, reveal, transformation, endings
    MapBuilder.luau    builds the manor, the mirror (with a mirrored room behind it) and yard
    Stalker.luau       act 1 AI: patrol, sight cone, hearing, wardrobe search
    Hiding.luau        wardrobes
    SearchParty.luau   act 3 AI: search, spot, flee to the car
    Rig.luau           NPC rigs, animation, "monsterize", pathfinding navigator
  client/
    init.client.luau   wiring
    Hud.luau           objective, subtitles, note reader, stamina, hunt stats, endings
    Controls.luau      sprint/stamina, flashlight, hunter sense
    Atmosphere.luau    flicker, heartbeat, vignette, flashlight, sirens, monster vision
    Cutscene.luau      mirror reveal, jumpscare, "taken" effect
    UI.luau            UI helpers
```
