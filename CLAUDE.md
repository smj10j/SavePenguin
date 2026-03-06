# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Save Penguin" (project name: Penguin Rescue) is a universal iOS game written in Objective-C. Players place toolbox items to guide penguins to safety while avoiding sharks. Built with Cocos2D, Box2D physics, and LevelHelper/SpriteHelper.

## Building

Open `Penguin Rescue.xcodeproj` in Xcode and build/run normally. CI uses:
```
xcodebuild -project "Penguin Rescue.xcodeproj" -scheme TravisCIScheme
```

There are no unit tests — testing is done by running on device/simulator.

## Architecture

### App Flow
`AppController` (AppDelegate) initializes `CCDirectorIOS` and sets the first scene to `BootLayer`. The scene progression is:

`BootLayer` → `IntroLayer` → `MainMenuLayer` → `LevelPackSelectLayer` → `LevelSelectLayer` → `GameLayer`

Side screens: `AboutLayer`, `InAppPurchaseLayer`, `ToolSelectLayer`

### GameLayer (core gameplay)
`GameLayer` is the main gameplay class. It manages:
- **Box2D world** (`b2World`) with a fixed physics step (`TARGET_PHYSICS_STEP = 0.03s`) using an accumulator
- **LevelHelper** (`LevelHelperLoader`) to load level scenes from `.plhs` files
- **Game states**: `SETUP → PLACE → RUNNING → GAME_OVER` (PAUSE available during RUNNING)
- **AI pathfinding**: Two separate grids (`_sharkMapfeaturesGrid`, `_penguinMapfeaturesGrid`) computed on a background GCD queue (`_moveGridUpdateQueue`). Grid size is at minimum `MIN_GRID_SIZE` (8).
- **Toolbox system**: Players drag tools from the toolbox into the world during the PLACE phase

### LevelHelper Custom Classes (`LevelHelper/CustomClasses/`)
Game entities defined as LevelHelper custom classes:
- `Penguin` — protagonist; properties: speed, alertRadius, detectionRadius, isInvisible, isSafe, hasSpottedShark, isStuck, isDead
- `Shark` — antagonist; properties: restingSpeed, activeSpeed, restingDetectionRadius, activeDetectionRadius, targetAcquired, isStuck
- `MovingBorder`, `MovingLand`, `MovingDoodad` — environmental elements
- `ToolboxItem_*` — placeable items: Bag_of_Fish, Debris, Invisibility_Hat, Loud_Noise, Obstruction, Sandbar, Whirlpool, Windmill

### Managers (`Penguin Rescue/Managers/`)
- `LevelPackManager` — level pack/level progression, unlock logic, completion tracking via NSUserDefaults
- `ScoreKeeper` / `Score` — scoring logic (max 15000 points; costs per second during place/run phases; Hand of God power cost)
- `IAPManager` — StoreKit in-app purchases (coin packs, level pack unlocks)
- `SettingsManager` — persistent user settings
- `APIManager` — backend API calls via ASIHTTPRequest
- `Analytics` — analytics event tracking

### Level Data
Levels are stored as LevelHelper scene files (`.plhs`) in:
```
Penguin Rescue/Resources/Levels/Pack{1,2,3}/<LevelName>.plhs
```
- `Packs.plist` — defines all level packs and unlock requirements
- `Pack{N}/Levels.plist` — ordered list of levels in each pack
- Menu scenes (MainMenu, LevelSelect, etc.) also use `.plhs` files in `Levels/Menu/`

### Spritesheets
Assets come in three resolutions (`@1x`, `-hd`/`@2x`, `-ipadhd`) for iPhone SD, iPhone Retina, and iPad Retina:
- `Spritesheet_Actors` — penguin, shark sprites
- `Spritesheet_Map` — terrain/level tiles
- `Spritesheet_Toolbox` — toolbox item sprites
- `Spritesheet_HUD` — in-game UI elements
- `Spritesheet_Menu` / `Spritesheet_MenuBackgrounds1` — menu UI

### Key Constants (`Penguin Rescue/Constants.h`)
- `APPSTORE_BUILD` / `DISTRIBUTION_MODE` — disables debug logging, enables analytics
- `TEST_MODE` + `TEST_LEVEL_PACK` / `TEST_LEVEL` — jump directly to a specific level during development
- `DEBUG_ALL_THE_THINGS` — enables all debug flags at once
- `PTM_RATIO` — Box2D pixels-to-meters: 32 (iPhone), 64 (iPad)
- `DebugLog()` macro — only outputs in non-distribution builds

### Coordinate System
The game is designed around iPad dimensions and scales down for iPhone using `SCALING_FACTOR_H` (480/1024) and `SCALING_FACTOR_V` (320/768). Always multiply UI layout values by the appropriate scaling factor constant.

### Third-Party Libraries
- `Penguin Rescue/libs/` — ASIHTTPRequest (networking), JSONKit (JSON parsing)
- `LevelHelper/` — LevelHelper SDK (level loading, physics integration)
- Cocos2D and Box2D are included as source in the project
