# Kinetic Forge

A Blender → Roblox pipeline for baked, deterministic rigid-body destruction. No manual rigging required.

The destruction is simulated in Blender, so it plays back the same way every time instead of depending on physics at runtime. Kinetic Forge fractures meshes into pieces and connects them with breakable rigid body constraints, so they hold together until something hits them hard enough.

Getting the baked result into Roblox is still in progress: the add-on currently covers the Blender side, from fracturing to running the simulation.

## Dependencies

### Regular dependencies

Needed to use Kinetic Forge.

| Dependency | Used for | How to get it |
|---|---|---|
| [Blender](https://www.blender.org/) 4.2 or newer | Running the add-on | blender.org |
| **Cell Fracture** extension | Cutting meshes into pieces | In Blender, **Edit > Preferences > Get Extensions**, search for "Cell Fracture". Kinetic Forge turns it on automatically if it's installed but disabled. |
| [Roblox Studio](https://create.roblox.com/) | Running the Roblox plugin, which rigs the pieces and turns the keyframes into an animation | create.roblox.com |
| [Roblox Blender plugin](https://github.com/Roblox/roblox-blender-plugin) (optional) | Uploading the pieces from Blender straight to Roblox | See [Uploading the pieces to Roblox](#uploading-the-pieces-to-roblox). You can import the meshes into Studio another way instead. |
| [Trove](https://github.com/Sleitnick/RbxUtil/tree/main/modules/trove) by Stephen Leitnick | Cleaning up the Roblox plugin's connections | Already included in `roblox/KineticForgeMain/Trove.luau` |
| NumPy | Finding touching pieces quickly | Comes with Blender |

### Dev dependencies

Only needed to work on Kinetic Forge itself.

| Dependency | Used for | How to get it |
|---|---|---|
| [Rokit](https://github.com/rojo-rbx/rokit) | Installing the pinned version of Rojo | Download from its Releases page and run `rokit self-install` |
| [Rojo](https://rojo.space/) 7.5 or newer | Building the Roblox plugin from `default.project.json`, and keeping `sourcemap.json` current | `rokit add rojo-rbx/rojo` in the repo root, which pins it in `rokit.toml` |
| [Visual Studio Code](https://code.visualstudio.com/) | Editor. The `.vscode/tasks.json` tasks rebuild the plugin on every save | code.visualstudio.com |
| [Luau Language Server](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) extension | Luau type checking and completions. `generate_style_types.py` also reads its Roblox type definitions | VS Code Extensions view |
| [Blender Development](https://marketplace.visualstudio.com/items?itemName=JacquesLucke.blender-development) extension | Running and reloading the add-on in Blender from VS Code | VS Code Extensions view |
| [Python](https://www.python.org/) and the Python and Pylance extensions | Python editing, and running `generate_style_types.py` | python.org, and the VS Code Extensions view |
| [`bpy`](https://pypi.org/project/bpy/) and [`fake-bpy-module`](https://pypi.org/project/fake-bpy-module/) | Blender API completions in VS Code | `pip install bpy` in `.venv`, and `pip install fake-bpy-module --target typings` |

### Building the Roblox plugin

While developing, the plugin runs from `PluginDebugService`, so changes reach Studio without reinstalling it:

1. Run the **Build plugin** task in VS Code (**Terminal > Run Task**). It installs `KineticForge.rbxm` into Studio's local plugins folder (`%LOCALAPPDATA%\Roblox\Plugins`).
2. Install Rojo's Studio plugin once with `rojo plugin install`.
3. In Studio, turn on **File > Studio Settings > Plugin Debugging Enabled**, and restart Studio. Each installed plugin now appears in `PluginDebugService`, Kinetic Forge as `user_KineticForge.rbxm`.
4. Run the **Watch plugin** task. It starts automatically when the folder opens. It runs `rojo serve debug.project.json`, and keeps `sourcemap.json` current.
5. In Studio, open the **Rojo** plugin and click **Connect**. Rojo syncs your changes into `user_KineticForge.rbxm`.

Rojo can't create the plugin itself, because only Studio can make the `Plugin` instances `PluginDebugService` holds. That's why the installed copy from step 1 is needed.

While it runs from `PluginDebugService`, the plugin reloads itself shortly after any of its modules change, so saving is enough. The entry script, `init.legacy.luau`, only creates the toolbar, button and widget and runs the reload. The plugin's own code is in `App.luau`. Anything App creates must go in its Trove, so a reload can remove it. Changes to `init.legacy.luau` itself still need the plugin reloaded by hand, in **Manage Plugins**.

A new module directly inside `roblox/KineticForgeMain` also needs an entry in `default.project.json`, since Rojo can't detect the plugin's `init.legacy.luau` script by name.

## Installing

1. Download the latest `.zip` from the Releases page.
2. In Blender, open **Edit > Preferences > Get Extensions**, then choose **Install from Disk** from the menu at the top right, and pick the `.zip`.

## Using it

The panel is in the 3D viewport's sidebar (press **N**), under the **Kinetic Forge** tab.

1. Select one or more meshes, set **Cells**, and click **Fracture**.
2. Select the pieces, set **Friction**, **Bounciness** and **Breaking Threshold**, and click **Apply** to give them rigid bodies and connect touching pieces. Click **Apply** again to change the settings later.
3. Play the animation to run the simulation.

Both buttons move the timeline back to the start frame, since changing rigid bodies partway through a simulation can crash Blender.

## Uploading the pieces to Roblox

Roblox's official [Blender plugin](https://github.com/Roblox/roblox-blender-plugin) uploads meshes from Blender straight to your Roblox inventory, so you don't have to export and import files by hand.

### Installing the Roblox plugin

You only need to do this once.

1. If you've installed an older version, remove it first. Open **Edit > Preferences > Add-ons**, search for "Roblox", expand **Upload to Roblox**, click **Uninstall**, and restart Blender.
2. Download the latest `.zip` from the plugin's [Releases page](https://github.com/Roblox/roblox-blender-plugin/releases). Don't unzip it.
3. In **Edit > Preferences > Add-ons**, click the **⌄** menu at the top right, choose **Install from Disk...**, and pick the `.zip`.
4. Search for "Roblox" and make sure **Upload to Roblox** is ticked.
5. In the 3D viewport's sidebar (press **N**), open the **Roblox** tab and click **Install Dependencies**.
6. When Blender reports "Installation complete!", restart Blender.
7. Back in **Edit > Preferences > Add-ons**, expand **Upload to Roblox** and untick **Bake Animation**. Kinetic Forge sends the motion to Roblox separately, so the upload only needs the meshes. With it ticked, uploading a collection of baked pieces can stop Blender responding for a long time, because the plugin exports every piece's animation onto every other piece.

### Signing in

1. In the **Roblox** tab, click **Log in**. Your browser opens a Roblox authorization page.
2. Log in, choose the account or groups you want to upload to, then click **CONTINUE** and **CONFIRM AND GIVE ACCESS**.
3. When the browser says you're logged in, close it and go back to Blender.
4. Pick where uploads go from the **Upload to:** dropdown.

### Uploading fractured pieces

1. **Go to the first frame of the simulation before uploading.** Kinetic Forge treats each piece's first-frame position as its starting pose, so the pieces in Roblox must be where they are on that frame.
2. Select the collection that holds the pieces. Fracturing puts them in a collection whose name starts with `kinetic_forge`. Selecting the collection uploads all the pieces as one asset. Selecting individual pieces instead uploads each one as a separate asset.
3. Click **Upload**.
4. In Roblox Studio, open **Toolbox > Inventory > My Packages**. The list isn't sorted, so search for the collection's name, then insert it.

The upload arrives as a package. To pull in later re-uploads automatically, select its `PackageLink` in Studio and turn on **AutoUpdate**. Updates overwrite any changes you made to it in Studio. Blender remembers which asset to update in the collection's **Roblox Package ID** custom property. Delete that property to upload as a new asset instead.
