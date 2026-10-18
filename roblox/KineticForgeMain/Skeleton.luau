--!strict
--!optimize 2
--!native

const ROOT_NAME = "KF_ROOT"
const ATTACHMENT_NAME = "KFAttachment"

const Skeleton = {}

function Skeleton.Generate(assembly: Model)
    const assemblyChildren = assembly:GetChildren()

    local positionSum = Vector3.zero
    const parts: { BasePart } = {}
    const partAttachments: { Attachment } = {}

    for _, child in assemblyChildren do
        if not child:IsA("BasePart") or child.Name == ROOT_NAME then
            continue
        end

        positionSum += child.Position
        -- Constraints can't move anchored parts, so only the root stays anchored
        child.Anchored = false

        local skeletonAttachment = child:FindFirstChild(ATTACHMENT_NAME) :: Attachment?

        if not skeletonAttachment then
            const attachment = Instance.new("Attachment")
            attachment.Name = ATTACHMENT_NAME
            -- The importer puts the pivot at the Blender object's origin, which is what the
            -- keyframes move. Only its position is used: the pivot's rotation is the
            -- importer's Z-up axis frame, not the object's rotation.
            attachment.CFrame = CFrame.new(child.PivotOffset.Position)
            attachment.Parent = child
            skeletonAttachment = attachment
        end

        table.insert(parts, child)
        table.insert(partAttachments, skeletonAttachment :: Attachment)
    end

    if #parts > 0 then
        local root = assembly:FindFirstChild(ROOT_NAME) :: BasePart?

        if not root then
            const newRoot = Instance.new("Part")
            newRoot.Name = ROOT_NAME
            newRoot.Size = Vector3.one * 2
            newRoot.Transparency = 1
            newRoot.CanCollide = false
            newRoot.Anchored = true
            newRoot.Position = positionSum / #parts
            newRoot.Parent = assembly
            root = newRoot
        end

        const rootPart = root :: BasePart
        rootPart.Anchored = true
        assembly.PrimaryPart = rootPart

        for i, part in parts do
            if part:FindFirstChildOfClass("AnimationConstraint") then
                continue
            end

            -- One attachment per part on the root, placed on the part's own attachment so
            -- an identity Transform leaves the part where it was modeled
            const rootAttachment = Instance.new("Attachment")
            rootAttachment.Name = part.Name
            rootAttachment.CFrame = rootPart.CFrame:ToObjectSpace(partAttachments[i].WorldCFrame)
            rootAttachment.Parent = rootPart

            const constraint = Instance.new("AnimationConstraint")
            constraint.Name = part.Name
            constraint.IsKinematic = true
            constraint.Attachment0 = rootAttachment
            constraint.Attachment1 = partAttachments[i]
            constraint.Parent = part
        end
    end

    -- The Animation Editor only recognizes models with a Humanoid or AnimationController
    local controller: Instance? = assembly:FindFirstChildOfClass("Humanoid")
        or assembly:FindFirstChildOfClass("AnimationController")

    if not controller then
        const newController = Instance.new("AnimationController")
        newController.Parent = assembly
        controller = newController
    end

    if controller and not controller:FindFirstChildOfClass("Animator") then
        const animator = Instance.new("Animator")
        animator.Parent = controller
    end
end

return Skeleton