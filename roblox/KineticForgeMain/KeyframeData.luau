--!strict
--!native
--!optimize 2
-- Decodes keyframe data copied from the Kinetic Forge Blender exporter and
-- poses an assembly's AnimationConstraints with it.

local HttpService = game:GetService("HttpService")

-- Must match the multipliers in the Blender exporter
local POSITION_SCALE = 10000
local ROTATION_SCALE = 100000

-- Must match ROOT_NAME in Skeleton
local ROOT_NAME = "KF_ROOT"

-- {px, py, pz, qx, qy, qz}, quantized to integers. The quaternion's w is dropped.
export type Keyframe = { number }

-- Each part's name mapped to its CFrame
export type Pose = { [string]: CFrame }

export type Animation = {
	fps: number,
	firstFrame: number,
	rest: Pose, -- each part on its first keyed frame, which matches the part as uploaded
	frames: { [number]: Pose },
}

-- How the importer turned and scaled the model relative to the data, found by FitToRig
export type RigFit = {
	rotation: CFrame,
	scale: number,
	offset: Vector3, -- where the data's origin landed in the rig
} 

local KeyframeData = {}

-- The 24 rotations that only swap and flip axes. Each importer converts Blender's axes with
-- one of these, so trying them all finds the right one for whichever importer was used.
local AXIS_ROTATIONS: { CFrame } = {}
do
	local axes = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }

	for _, right in axes do
		for _, up in axes do
			if math.abs(right:Dot(up)) < 0.5 then
				-- fromMatrix works out Z from X and Y, so every result is a rotation, not a mirror
				table.insert(AXIS_ROTATIONS, CFrame.fromMatrix(Vector3.zero, right, up))
			end
		end
	end
end

-- Blender is Z-up and Roblox is Y-up. Must match how the Roblox importer places meshes,
-- which turns Blender's X and Y around, so (x, y, z) -> (-x, z, y). This is still a
-- rotation, so it also converts a quaternion's x, y, z.
local function ToRobloxAxes(x: number, y: number, z: number): (number, number, number)
	return -x, z, y
end

function KeyframeData.ToCFrame(keyframe: Keyframe): CFrame
	local px, py, pz = ToRobloxAxes(
		keyframe[1] / POSITION_SCALE,
		keyframe[2] / POSITION_SCALE,
		keyframe[3] / POSITION_SCALE
	)
	local qx, qy, qz = ToRobloxAxes(
		keyframe[4] / ROTATION_SCALE,
		keyframe[5] / ROTATION_SCALE,
		keyframe[6] / ROTATION_SCALE
	)
	-- The exporter flips the quaternion so w is never negative, so w can be rebuilt
	-- from the unit length. Rounding can push the sum just over 1, hence the max.
	local qw = math.sqrt(math.max(0, 1 - qx * qx - qy * qy - qz * qz))

	return CFrame.new(px, py, pz, qx, qy, qz, qw)
end

-- Parses the string pasted from Blender. Errors if it isn't valid JSON.
function KeyframeData.Decode(json: string): Animation
	local raw = HttpService:JSONDecode(json)
	if type(raw) ~= "table" or type(raw.fps) ~= "number" or type(raw.frames) ~= "table" then
		error("Keyframe data must be {fps, frames}. Re-export it from Blender.", 2)
	end

	local animation: Animation = {
		fps = raw.fps,
		firstFrame = math.huge,
		rest = {},
		frames = {},
	}
	-- JSON tables have no order, so track each part's earliest frame to find its rest pose
	local firstFrames: { [string]: number } = {}

	for frameKey, keyframes in raw.frames do
		-- JSON object keys are always strings
		local frame = tonumber(frameKey) :: number
		local pose: Pose = {}

		for name, keyframe in keyframes do
			if type(keyframe) ~= "table" or #keyframe ~= 6 then
				error(`Frame {frameKey}, part {name}: expected [px, py, pz, qx, qy, qz]`, 2)
			end

			local cframe = KeyframeData.ToCFrame(keyframe)
			pose[name] = cframe

			if frame < (firstFrames[name] or math.huge) then
				firstFrames[name] = frame
				animation.rest[name] = cframe
			end
		end

		animation.frames[frame] = pose
		animation.firstFrame = math.min(animation.firstFrame, frame)
	end

	-- Blender's bake deletes keyframes that don't change anything, so a gap with the same pose on
	-- both sides means the part was holding still. Fill those frames with that pose. Otherwise the
	-- Animator interpolates across the gap, which can turn a part that should be still, e.g. one
	-- flipped ~180°. Gaps where the pose changes, like a hand-keyed object, are left to interpolate.
	local frameOrder: { number } = {}
	for frame in animation.frames do
		table.insert(frameOrder, frame)
	end
	table.sort(frameOrder)

	-- Each part's last keyed pose, and the frames since then where it had none
	local lastPose: Pose = {}
	local missing: { [string]: { number } } = {}

	for _, frame in frameOrder do
		local pose = animation.frames[frame]

		for name, cframe in pose do
			local gap = missing[name]
			-- 0.01 allows for rounding in the export, which near a 180° turn makes equal poses
			-- differ by up to about 0.004
			if gap and #gap > 0 and lastPose[name]:FuzzyEq(cframe, 1e-2) then
				-- Use the exact pose from before the gap throughout, including on the frame that ends
				-- it. Near 180° even that rounding difference can make the Animator spin the part
				-- the long way round, so a still stretch must not differ at all.
				const held = lastPose[name]
				for _, gapFrame in gap do
					animation.frames[gapFrame][name] = held
				end
				pose[name] = held
				cframe = held
			end

			lastPose[name] = cframe
			missing[name] = {}
		end

		-- Only parts already seen, so nothing gets a pose before its first keyframe
		for name in lastPose do
			if not pose[name] then
				table.insert(missing[name], frame)
			end
		end
	end

	-- Blender holds a part's last pose to the end, so do the same after its last keyframe
	for name, gap in missing do
		for _, gapFrame in gap do
			animation.frames[gapFrame][name] = lastPose[name]
		end
	end

	return animation
end

-- Maps each part's name to the AnimationConstraint that drives it. The driven part
-- is the one holding Attachment1.
function KeyframeData.GetConstraints(assembly: Model): { [string]: AnimationConstraint }
	local primaryPart = assembly.PrimaryPart
	if not primaryPart or primaryPart.Name ~= ROOT_NAME then
		error(`{assembly:GetFullName()} has no {ROOT_NAME} primary part. Generate its skeleton first.`, 2)
	end

	local constraints: { [string]: AnimationConstraint } = {}

	for _, descendant in assembly:GetDescendants() do
		if not descendant:IsA("AnimationConstraint") then
			continue
		end

		local attachment1 = descendant.Attachment1
		local part1 = attachment1 and attachment1.Parent
		if part1 then
			constraints[part1.Name] = descendant
		end
	end

	return constraints
end

-- Finds how the importer turned and scaled the model, by matching where each part starts in
-- the data to where its joint sits in the rig. Needs at least 3 parts to tell the axes apart.
function KeyframeData.FitToRig(animation: Animation, constraints: { [string]: AnimationConstraint }): RigFit?
	local from: { Vector3 } = {}
	local to: { Vector3 } = {}

	for name, rest in animation.rest do
		local constraint = constraints[name]
		local attachment0 = constraint and constraint.Attachment0

		if attachment0 then
			table.insert(from, rest.Position)
			table.insert(to, attachment0.WorldPosition)
		end
	end

	if #from < 3 then
		return nil
	end

	-- Compare the shapes around their centres, so where the model was placed doesn't matter
	local fromCentre, toCentre = Vector3.zero, Vector3.zero
	for i = 1, #from do
		fromCentre += from[i]
		toCentre += to[i]
	end
	fromCentre /= #from
	toCentre /= #to

	local spread = 0
	for i = 1, #from do
		local p = from[i] - fromCentre
		spread += p:Dot(p)
	end

	if spread == 0 then
		return nil
	end

	local best: RigFit? = nil
	local bestError = math.huge

	for _, rotation in AXIS_ROTATIONS do
		-- The scale that best fits this rotation, by least squares
		local dot = 0
		for i = 1, #from do
			dot += rotation:VectorToWorldSpace(from[i] - fromCentre):Dot(to[i] - toCentre)
		end

		local scale = dot / spread
		if scale <= 0 then
			continue
		end

		local fitError = 0
		for i = 1, #from do
			local miss = (to[i] - toCentre) - rotation:VectorToWorldSpace(from[i] - fromCentre) * scale
			fitError += miss:Dot(miss)
		end

		if fitError < bestError then
			bestError = fitError
			best = {
				rotation = rotation,
				scale = scale,
				offset = toCentre - rotation:VectorToWorldSpace(fromCentre) * scale,
			}
		end
	end

	return best
end

-- Turns and scales every pose by the fit, so the data matches the rig. Rotations are turned
-- into the rig's axes too, rather than just moved, so they spin about the right axes.
function KeyframeData.ApplyFit(animation: Animation, fit: RigFit): Animation
	local function Convert(cframe: CFrame): CFrame
		local position = fit.rotation:VectorToWorldSpace(cframe.Position) * fit.scale
		return CFrame.new(position) * (fit.rotation * cframe.Rotation * fit.rotation:Inverse())
	end

	local fitted: Animation = {
		fps = animation.fps,
		firstFrame = animation.firstFrame,
		rest = {},
		frames = {},
	}

	for name, cframe in animation.rest do
		fitted.rest[name] = Convert(cframe)
	end

	for frame, pose in animation.frames do
		local fittedPose: Pose = {}
		for name, cframe in pose do
			fittedPose[name] = Convert(cframe)
		end
		fitted.frames[frame] = fittedPose
	end

	return fitted
end

-- Poses every part that has a keyframe on this frame. Transforms are relative to
-- each part's rest pose, which assumes the skeleton places Attachment0 at the part's
-- rest offset from its parent part and leaves Attachment1 at the part's origin.
function KeyframeData.ApplyFrame(constraints: { [string]: AnimationConstraint }, animation: Animation, frame: number)
	local pose = animation.frames[frame]
	if not pose then
		return
	end

	for name, cframe in pose do
		local constraint = constraints[name]

		if constraint then
			constraint.Transform = animation.rest[name]:Inverse() * cframe
		end
	end
end

-- Builds a KeyframeSequence from the animation. Every part's constraint hangs off the
-- root, so each Keyframe holds a root Pose with one child Pose per part.
function KeyframeData.ApplyAnimationDataToAssembly(animation: Animation, assembly: Model): KeyframeSequence
	-- Also errors if the assembly has no skeleton
	const constraints = KeyframeData.GetConstraints(assembly)

	-- Match the data to however the importer turned and scaled this model
	const fit = KeyframeData.FitToRig(animation, constraints)
	if fit then
		animation = KeyframeData.ApplyFit(animation, fit)
	end

	const clip = Instance.new("KeyframeSequence")
	clip.Name = assembly.Name
	-- A simulation plays once and stays on its last frame
	clip.Loop = false

	-- In order, so each part's pose can be compared with its pose on the previous keyframe
	const frameOrder: { number } = {}
	for frameNum in animation.frames do
		table.insert(frameOrder, frameNum)
	end
	table.sort(frameOrder)

	-- Each part's previous Pose, and its rotation as the quaternion Roblox interpolates with. This
	-- module's own Pose type hides Roblox's Pose class, hence typeof.
	const previousPoses: { [string]: typeof(Instance.new("Pose")) } = {}
	const previousRotations: { [string]: { number } } = {}

	for _, frameNum in frameOrder do
		const frame = animation.frames[frameNum]
		const keyframe = Instance.new("Keyframe")
		-- Shift so the clip starts at 0 even if Blender's first key isn't on frame 0
		keyframe.Time = (frameNum - animation.firstFrame) / animation.fps
		keyframe.Parent = clip

		const rootPose = Instance.new("Pose")
		rootPose.Name = ROOT_NAME
		rootPose.Parent = keyframe

		for objName, objCFrame in frame do
			-- Skip parts the rig has no joint for
			if not constraints[objName] then
				continue
			end

			-- Same rest-relative offset ApplyFrame writes to Transform
			const pose = Instance.new("Pose")
			pose.Name = objName
			pose.CFrame = animation.rest[objName]:Inverse() * objCFrame
			pose.Parent = rootPose

			-- Roblox turns each pose into the quaternion with w >= 0 to interpolate. When a part's
			-- rotation passes through 180° between two keyframes, those quaternions point opposite
			-- ways, so interpolating goes the long way round: a spin of ~350° in one frame. Hold the
			-- previous pose until this one instead. The real turn is small, so the step isn't seen.
			const axis, angle = pose.CFrame:ToAxisAngle()
			const rotation = { math.cos(angle / 2), axis.X * math.sin(angle / 2), axis.Y * math.sin(angle / 2), axis.Z * math.sin(angle / 2) }
			const previous = previousRotations[objName]

			if previous then
				const dot = previous[1] * rotation[1] + previous[2] * rotation[2] + previous[3] * rotation[3] + previous[4] * rotation[4]
				if dot < 0 then
					previousPoses[objName].EasingStyle = Enum.PoseEasingStyle.Constant
				end
			end

			previousPoses[objName] = pose
			previousRotations[objName] = rotation
		end
	end

	return clip
end

-- Prints how the data was fitted to the rig, and warns about parts that still start in the
-- wrong place after fitting, or have no joint.
function KeyframeData.CheckRig(animation: Animation, assembly: Model)
	const constraints = KeyframeData.GetConstraints(assembly)
	const fit = KeyframeData.FitToRig(animation, constraints)

	if not fit then
		warn("Fewer than 3 parts match the rig, so the axes and scale can't be fitted. Using the data as it is.")
	else
		const x, y, z = fit.rotation:ToOrientation()
		print(`Fitted the data to the rig: turned ({math.round(math.deg(x))}, {math.round(math.deg(y))}, {math.round(math.deg(z))}) deg, scale {math.round(fit.scale * 1000) / 1000}`)
	end

	local worstName, worstMiss = nil, 0

	for name, rest in animation.rest do
		const constraint = constraints[name]
		const attachment0 = constraint and constraint.Attachment0
		if not attachment0 then
			warn(`{name}: no joint in the rig`)
			continue
		end

		if fit then
			-- The root is anchored, so this is the rest position however far the clip has played
			const expected = fit.offset + fit.rotation:VectorToWorldSpace(rest.Position) * fit.scale
			const miss = (attachment0.WorldPosition - expected).Magnitude

			if miss > worstMiss then
				worstName, worstMiss = name, miss
			end
		end
	end

	-- Small misses are rounding. Large ones mean a part doesn't match its Blender object.
	if worstName and worstMiss > 0.05 then
		warn(`{worstName} starts {math.round(worstMiss * 1000) / 1000} studs from where the data puts it, the furthest of any part`)
	end
end

return KeyframeData
