# RBLXGame — Hero Roleplay Framework

[![Rojo Version](https://img.shields.io/badge/Rojo-7.7.1-blue.svg?style=flat-square)](https://rojo.space/)
[![Luau](https://img.shields.io/badge/Luau-Strict%20Typing-00A2FF.svg?style=flat-square)](https://luau-lang.org/)
[![Roblox](https://img.shields.io/badge/Platform-Roblox%20R15-red.svg?style=flat-square)](https://create.roblox.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

**RBLXGame** is an enterprise-grade, modular Roblox Roleplay Game foundation built with **Rojo 7.7.1** and strict **Luau**. It provides an extensible multi-hero architecture, procedural and mesh-compatible R15 character loading, server-authoritative ability mechanics with client-side prediction, and an asset pipeline ready for studio sync.

---

## Featured Hero: Stormforge Valen
* **Role**: Legendary Lightning Warrior / Fantasy Hero
* **Signature Weapon**: Stormforge Warhammer (Oversized fantasy hammer with suspended cyan neon core and spark emitters)
* **Abilities**:
  * `[E]` **Lightning Strike**: Vertical skyward thunderbolt with radial discharge.
  * `[Q]` **Thunder Hammer Slam**: Leaps forward and drives the warhammer into the ground, expanding a shockwave ring.
  * `[F]` **Storm Shield**: Electrostatic forcefield sphere absorbing damage for 4 seconds.
  * `[Shift]` **Lightning Dash**: High-speed 30-stud surge leaving an electric neon discharge trail.

---

## Project Structure

```
RBLXGame/
├── .vscode/
│   ├── extensions.json             # Recommended extensions (Luau LSP, Rojo, Error Lens)
│   └── settings.json               # Luau LSP Roblox typecheck & sourcemap integration
├── src/
│   ├── assets/
│   │   ├── Characters/
│   │   │   └── StormforgeValen/
│   │   │       ├── Accessories/    # Upgraded compound accessories (Hair, Chestplate, Pauldrons, Cape, Boots, Gauntlets)
│   │   │       ├── Animations/     # Animation instances (Idle, Walk, Run, Jump, Attack, Ability)
│   │   │       ├── Meshes/         # Wavefront .OBJ 3D models ready for Blender/Studio import
│   │   │       ├── Textures/       # PBR Texture manifests & hex color palette configs
│   │   │       └── Weapons/        # Stormforge Warhammer Tool
│   │   ├── Effects/                # VFX emitter templates
│   │   └── Weapons/                # Weapons folder
│   ├── client/
│   │   ├── AbilityController.client.lua    # Input detection, local prediction & VFX renderers
│   │   ├── AnimationController.client.lua  # Animation track loading & priority management
│   │   ├── CharacterController.client.lua  # Hero Selection GUI modal & camera
│   │   └── Main.client.lua                 # Client bootstrap
│   ├── server/
│   │   ├── AbilityService.server.lua       # Server cooldown validation, anti-exploit & VFX replication
│   │   ├── CharacterService.server.lua     # Spawner service & character lifecycle
│   │   ├── Main.server.lua                 # Server bootstrap
│   │   └── SpawnService.server.lua         # Player connection handler
│   └── shared/
│       ├── AbilityConfig.lua               # Ability definitions, cooldowns, and keys
│       ├── CharacterLoader.lua             # R15 rig procedural builder, scaler & accessory welder
│       ├── CharacterRegistry.lua           # Extensible hero registry (Valen, SolarWarrior, ShadowNinja...)
│       ├── SharedConstants.lua             # Global constants
│       ├── StormforgeValenConfig.lua       # Valen stats, colors, scaling, and accessory map
│       └── Types.lua                       # Strict Luau type declarations
├── .editorconfig                           # 4-space indentation, LF endings
├── .gitignore                              # Roblox build artifacts & temporary files ignore
├── default.project.json                    # Rojo DataModel mapping configuration
└── README.md
```

---

## Getting Started

### Prerequisites
1. **[Rojo 7.7.1+](https://rojo.space/)**: Installed via WinGet (`winget install Rojo.Rojo`), Aftman, or Cargo.
2. **[Visual Studio Code](https://code.visualstudio.com/)**: With the following extensions installed:
   * **Luau Language Server** (`JohnnyMorganz.luau-lsp`)
   * **Rojo for VS Code** (`evaera.vscode-rojo`)
3. **[Roblox Studio](https://create.roblox.com/)**: With the **Rojo 7** Studio plugin installed.

### Running the Project with Rojo

1. Clone the repository:
   ```bash
   git clone https://github.com/gameszoom325-cell/RBLXGame.git
   cd RBLXGame
   ```

2. Start the Rojo development server:
   ```powershell
   rojo serve
   ```
   *Expected output:*
   ```text
   [INFO] Listening on 127.0.0.1:34872
   ```

3. Connect in Roblox Studio:
   * Open Roblox Studio with a blank **Baseplate** (or your existing place).
   * In the **Plugins** ribbon, open **Rojo**.
   * Confirm the port is `34872` and click **Connect**.
   * The explorer will immediately sync `ServerScriptService`, `StarterPlayerScripts`, and `ReplicatedStorage` (with `Shared` and `Assets`).

4. Test in Studio:
   * Press **Play (F5)**.
   * The interactive **"CHOOSE YOUR HERO"** interface will appear.
   * Click **"SPAWN AS STORMFORGE VALEN"** to morph into the broad-shouldered hero equipped with the Stormforge Warhammer!
   * Press `1` to equip the hammer, and test keys `Q`, `E`, `F`, and `LeftShift` for abilities.

---

## Development Status

| Milestone | Status | Description |
| :--- | :---: | :--- |
| **Phase 1: Project Scaffolding & Tooling** | Complete | Rojo 7.7.1 setup, Luau LSP configuration, `.vscode` settings. |
| **Phase 2: R15 Rigging & Character Pipeline** | Complete | Procedural 15-joint R15 builder, scaling engine, accessory welder. |
| **Phase 3: Hero Config & Registry** | Complete | Extensible data model supporting instant addition of new heroes. |
| **Phase 4: Ability Engine & Network Security** | Complete | Server-authoritative cooldown validation, client prediction, VFX replication. |
| **Phase 5: Production Character Assets** | Complete | Multi-tone compound accessories, neon cyan conductors, 3D Wavefront OBJs. |
| **Phase 6: Audio & Custom Mocap Animations** | In Progress | Planned keyframed attack animations and sound effects. |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
