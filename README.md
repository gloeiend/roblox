# Roblox games

This repo has two games, each a standalone [Rojo](https://rojo.space) project:

- **Sky Climb** (this folder): a 40-stage obby with coins, upgrades and rebirths.
- **[Hollow Manor](hollow-manor/)**: a story horror game where you end up as the villain.

# Sky Climb

A complete Roblox obby built entirely in code with [Rojo](https://rojo.space).
Climb 40 procedurally generated stages across four zones, grab coins, buy
upgrades and trails, then rebirth for a permanent coin multiplier.

## Features

- **40 stages, 4 zones** – Meadow, Dunes, Frostpeak and Emberforge, each with its own palette.
  Difficulty ramps smoothly from the first stage to the last.
- **7 obstacle types** – platform jumps, lava strips, tightropes, moving platforms,
  spinning kill bars, crumbling platforms and truss towers. The course is generated from a
  fixed seed (`Config.SEED`), so every server gets the same layout.
- **Checkpoints** with coin rewards, and a void rescue that puts you back on your
  checkpoint instead of making you wait for a respawn.
- **Coins** that each player collects separately (they respawn after 40s), with
  sparkles and sound.
- **Shop** (button or `B` key)
  - Swift Shoes – walk speed
  - Spring Boots – jump power
  - Coin Magnet – pickup radius
  - Five cosmetic trails
- **Rebirths** – reach the finish, rebirth to restart and earn +50% coins per rebirth.
- **Saving** via DataStores (coins, stage, upgrades, trails, rebirths) with retries,
  autosave and save-on-shutdown. Works offline in Studio without saving.
- Responsive HUD that scales for phone, tablet and desktop.
- All purchases and progress are validated on the server.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit) (or install Rojo directly), then run
   `rokit install` in this folder.
2. Either:
   - **Build a place file:** `rojo build -o SkyClimb.rbxl` and open it in Roblox Studio, or
   - **Live sync:** open a new Baseplate in Studio, install the Rojo Studio plugin, run
     `rojo serve` and click *Connect* in the plugin.
3. Press **Play**. The course builds itself when the server starts.

To have progress save, publish the place and enable
*Game Settings → Security → Enable Studio Access to API Services*.

## Project layout

```
src/
  shared/Config.luau          All tuning: stages, zones, prices, rewards
  server/
    init.server.luau          Entry point: lighting, course build, services
    CourseBuilder.luau        Lobby, stages, checkpoints, coins, finish
    Obstacles.luau            One generator per obstacle type
    PlayerService.luau        Checkpoints, coins, shop, trails, rebirths
    DataService.luau          DataStore load/save
  client/
    init.client.luau          Entry point
    HUD.luau                  Coins, progress bar, buttons, toasts
    Shop.luau                 Upgrades + trails window
    Effects.luau              Coin spin, pickups, celebrations
    UI.luau                   UI building helpers
```

## Tweaking

Everything lives in `src/shared/Config.luau`: change `STAGE_COUNT` for a longer or shorter
course, `SEED` for a different layout, or adjust upgrade prices, trail costs and rewards.
To add an obstacle, write a generator in `Obstacles.luau` and add its name to `POOL` in
`CourseBuilder.luau`.

## Type checking

```
rojo sourcemap -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```

(`globalTypes.d.luau` comes from the luau-lsp repository.) All scripts use `--!strict`.
