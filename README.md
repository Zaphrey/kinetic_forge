# Kinetic Forge

A Blender → Roblox pipeline for baked, deterministic rigid-body destruction. No manual rigging required.

The destruction is simulated in Blender, so it plays back the same way every time instead of depending on physics at runtime. Kinetic Forge fractures meshes into pieces and connects them with breakable rigid body constraints, so they hold together until something hits them hard enough.

Getting the baked result into Roblox is still in progress: the add-on currently covers the Blender side, from fracturing to running the simulation.

## Requirements

- Blender 4.2 or newer
- The **Cell Fracture** extension, which does the cutting. Install it in Blender from **Edit > Preferences > Get Extensions**, by searching for "Cell Fracture". Kinetic Forge turns it on automatically if it's installed but disabled.

## Installing

1. Download the latest `.zip` from the Releases page.
2. In Blender, open **Edit > Preferences > Get Extensions**, then choose **Install from Disk** from the menu at the top right, and pick the `.zip`.

## Using it

The panel is in the 3D viewport's sidebar (press **N**), under the **Kinetic Forge** tab.

1. Select one or more meshes, set **Cells**, and click **Fracture**.
2. Select the pieces, set **Friction**, **Bounciness** and **Breaking Threshold**, and click **Apply** to give them rigid bodies and connect touching pieces. Click **Apply** again to change the settings later.
3. Play the animation to run the simulation.

Both buttons move the timeline back to the start frame, since changing rigid bodies partway through a simulation can crash Blender.
