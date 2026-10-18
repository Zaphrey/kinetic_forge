--!strict
--!native
--!optimize 2
-- The plugin itself. KineticForgeMain starts it, and starts it again from fresh copies of
-- the modules whenever their code changes, so everything it makes must go in the Trove it's
-- given. KineticForgeMain cleans that Trove up, even when starting fails partway through.
const Selection = game:GetService("Selection")

const KeyframeData = require("./KeyframeData")
const SequencePlayer = require("./SequencePlayer")
const Skeleton = require("./Skeleton")
const Types = require("./UIParser/Types")
const PluginTypes = require("./Types")
const TroveModule = require("./Trove")
const RBXMLParser = require("./UIParser")
const RBXML_DOCUMENT = require("./Markup")

print("Kinetic Forge Updated") 

type Assembly = PluginTypes.Assembly

return function(_plugin: Plugin, widget: DockWidgetPluginGui, button: PluginToolbarButton, Trove: TroveModule.Trove)

    local animationData: KeyframeData.Animation? = nil
    -- The preview that's playing, so starting another one can stop it first
    local activePreview: TroveModule.Trove? = nil
    -- The clip and rig last previewed, which Reset Pose puts back on the first frame
    local previewSequence: KeyframeSequence? = nil
    local previewAssembly: Assembly? = nil

    const function BuildUI(documentSource: Types.DocumentSource): (Types.Document, RBXMLParser.Page)
        -- Build main UI
        if documentSource.styles then
            const styles = Trove:Add(documentSource.styles:Clone()) 
            styles.Parent = widget

            const styleLink = Trove:Add(Instance.new("StyleLink"))
            styleLink.StyleSheet = styles
            styleLink.Parent = widget
        end

        const document = RBXMLParser.ParseDocument(documentSource)
        const content = RBXMLParser.Render(document)

        for _, element in content.rendered do
            Trove:Add(element) 
            element.Parent = widget
        end

        return document, content
    end

    const _DOCUMENT, PAGE = BuildUI(RBXML_DOCUMENT)

    -- Done with preliminaries ---------------------------------------------------------------------------------------------------------------------------------------------------------------

    const function OnWidgetToggled()
        widget.Enabled = not widget.Enabled
    end

    const function GetSelectedAssemblies(): { Model }
        const selected: { Model } = {}

        for _, object in Selection:Get() do
            -- Any model with at least one part directly inside it, whatever else it holds.
            -- Skeleton.Generate only rigs a model's direct children, so nested parts don't count.
            if object:IsA("Model") and object:FindFirstChildWhichIsA("BasePart") then
                table.insert(selected, object)
            end
        end

        return selected
    end

    -- Greys out and blocks the button through the "disabled" style
    const function SetButtonEnabled(id: string, conditionName: string, enabled: boolean)
        const node = PAGE.GetObjectById(id)
        const element = node and node.element

        if not element then
            return
        end

        -- print(conditionName, typeof(conditionName), enabled)
        element:SetAttribute(`active_{conditionName:lower()}`, enabled)

        local allAttributesActive = true

        for attribute, active in element:GetAttributes() do
            if attribute:sub(1, 6) == "active" and not active then
                allAttributesActive = false
                break
            end
        end

        if allAttributesActive then
            element:RemoveTag("disabled")
        else
            element:AddTag("disabled")
        end
    end

    const function OnSelectionChanged()
        const selected = GetSelectedAssemblies()

        -- Generating rigs every selected assembly, but importing only applies to one
        SetButtonEnabled("generate-skeleton-button", "selected", #selected > 0)
        SetButtonEnabled("import-keyframes-button", "selected", #selected == 1)
        SetButtonEnabled("import-keyframes-button", "animationdata", animationData ~= nil)
        SetButtonEnabled("reset-pose-button", "preview", previewSequence ~= nil)

        const detected = PAGE.GetObjectById("detected-assemblies")
        const detectedElement = detected and detected.element

        if detectedElement and detectedElement:IsA("TextLabel") then
            detectedElement.Text = `Detected assemblies: {#selected}`
        end
    end

    Trove:Connect(((PAGE.GetObjectById("generate-skeleton-button") :: Types.Node).element :: TextButton).MouseButton1Click, function(...): ...any
        const assemblies = GetSelectedAssemblies()

        for _, assembly in assemblies do
            Skeleton.Generate(assembly)
        end
    end)

    const databox = (PAGE.GetObjectById("data-box") :: Types.Node).element :: TextBox

    Trove:Connect(databox:GetPropertyChangedSignal("Text"), function(...): ...any
        -- Text also changes when the box is cleared, which isn't data to decode
        if databox.Text == "" then
            return 
        end

        const s, result = xpcall(KeyframeData.Decode, function(err)
            databox.Text = ""
            -- No point in sending errors to the output, they get swallowed on live instances.
            -- TODO: Add a disclaimer box if the user tries to input invalid data
        end, databox.Text)

        -- Only keep the data here. Which rig it plays on is decided when Import Keyframes is
        -- clicked, so it can be applied to any rig, including copies selected later.
        animationData = if s then result else nil
        SetButtonEnabled("import-keyframes-button", "animationdata", animationData ~= nil)
    end)

    -- The rig to play on: the one selected model, if it has been rigged with an Animator
    const function GetSelectedRig(): Assembly?
        const selected = GetSelectedAssemblies()
        if #selected ~= 1 then
            return nil
        end

        const controller = selected[1]:FindFirstChildOfClass("AnimationController")
        if not controller or not controller:FindFirstChildOfClass("Animator") then
            return nil
        end

        return selected[1] :: Assembly
    end

    const importKeyframes = (PAGE.GetObjectById("import-keyframes-button") :: Types.Node).element :: TextButton

    Trove:Connect(importKeyframes.MouseButton1Click, function(...): ...any
        const data = animationData
        if not data then
            return
        end

        const assembly = GetSelectedRig()
        if not assembly then
            warn("Select one rig with a generated skeleton to play the keyframes on.")
            return
        end

        const sequence = KeyframeData.ApplyAnimationDataToAssembly(data, assembly)
        KeyframeData.CheckRig(data, assembly)

        -- Otherwise every click adds another stepping loop on top of the last. Cleaning it up also
        -- puts the rig it was playing on back in its rest pose, even when that's a different rig.
        if activePreview then
            activePreview:Destroy()
        end

        activePreview = SequencePlayer.LoadSequence(sequence, assembly, Trove)
        previewSequence = sequence
        previewAssembly = assembly
        SetButtonEnabled("reset-pose-button", "preview", true)
    end)

    const resetPose = (PAGE.GetObjectById("reset-pose-button") :: Types.Node).element :: TextButton

    -- Puts the previewed rig back on the animation's first frame, by holding the clip at time 0.
    -- Setting joints directly doesn't move anything in Edit mode, and neither does stepping
    -- the Animator with nothing playing.
    Trove:Connect(resetPose.MouseButton1Click, function(...): ...any
        const sequence, assembly = previewSequence, previewAssembly
        if not sequence or not assembly then
            return
        end

        -- Stop the preview first, or its next step would pose the pieces again
        if activePreview then
            activePreview:Destroy()
        end

        activePreview = SequencePlayer.ShowFirstFrame(sequence, assembly, Trove)
    end)
    
    Trove:Connect(Selection.SelectionChanged, OnSelectionChanged)
    Trove:Connect(button.Click, OnWidgetToggled)

    -- Show the current selection straight away, rather than after it next changes
    OnSelectionChanged()
end
