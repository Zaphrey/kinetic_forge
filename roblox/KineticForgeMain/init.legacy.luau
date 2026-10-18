--!strict
--!native
--!optimize 2
-- Creates what Studio only lets a plugin make once, then starts App with it. When the plugin
-- runs from PluginDebugService, it also starts App again whenever a module's code changes,
-- so edits synced in by Rojo show up without reloading the plugin.

-- How long to wait for more changes before reloading, since one sync can touch several files
const RELOAD_DELAY = 0.2

const TOOLBAR = plugin:CreateToolbar("Kinetic Forge")
const TOGGLE_BUTTON = TOOLBAR:CreateButton("KineticForge1", "Toggle Widget", "")

const WIDGET = plugin:CreateDockWidgetPluginGuiAsync("KineticForge", DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Left,
    false,
    true,
    300,
    300,
    300,
    300
))

WIDGET.Title = "Kinetic Forge v0.0.0"

-- What App returns: starts the plugin, putting everything it makes in the given Trove
type StartApp = (Plugin, DockWidgetPluginGui, PluginToolbarButton, any) -> ()

-- The running App's Trove. Owned here rather than by App, so it's still cleaned up when
-- App errors partway through starting, after it has already connected signals.
local trove: any = nil

const function Start()
    if trove then
        trove:Destroy()
        trove = nil
    end

    -- require caches each module by instance, so fresh copies are what load the new code
    const fresh = Instance.new("Folder")
    for _, child in script:GetChildren() do 
        child:Clone().Parent = fresh
    end

    -- The copies aren't paths the type checker can follow, so their types are given here
    const newTrove = (require :: any)(fresh:FindFirstChild("Trove")).new()
    trove = newTrove

    -- A save with an error only warns. The next save tries again.
    const success, err = pcall(function()
        const startApp = (require :: any)(fresh:FindFirstChild("App")) :: StartApp
        startApp(plugin, WIDGET, TOGGLE_BUTTON, newTrove)
    end)

    if not success then
        -- Remove whatever App made before it failed, so it can't keep running alongside later reloads
        newTrove:Destroy()
        trove = nil
        warn(`Kinetic Forge failed to start: {err}`)
    end
end

-- Only reload while developing. An installed copy's code never changes.
if script:FindFirstAncestorOfClass("PluginDebugService") then
    local pending = 0

    const function QueueReload()
        pending += 1
        const token = pending

        task.delay(RELOAD_DELAY, function()
            -- A later change queued its own reload
            if token == pending then
                Start()
            end
        end)
    end

    const function Watch(instance: Instance)
        if instance:IsA("LuaSourceContainer") then
            instance.Changed:Connect(function(property)
                if property == "Source" then
                    QueueReload()
                end
            end)
        end
    end

    for _, descendant in script:GetDescendants() do
        Watch(descendant)
    end

    script.DescendantAdded:Connect(function(descendant)
        Watch(descendant)
        QueueReload()
    end)
    script.DescendantRemoving:Connect(QueueReload)
end

plugin.Unloading:Once(function()
    if trove then
        trove:Destroy()
    end
end)

Start()

-- Only on the first start, so reloads don't hide or show the widget
WIDGET.Enabled = true
