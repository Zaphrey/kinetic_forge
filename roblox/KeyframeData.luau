--!strict
--!native
--!optimize 2
-- Decodes keyframe data copied from the Kinetic Forge Blender exporter and
-- poses an assembly's Motor6Ds with it.

local HttpService = game:GetService("HttpService")

-- Must match the multipliers in the Blender exporter
local POSITION_SCALE = 10000
local ROTATION_SCALE = 100000

-- {px, py, pz, qx, qy, qz}, quantized to integers. The quaternion's w is dropped.
export type Keyframe = { number }

export type Track = {
	rest: CFrame, -- pose on the first frame, which matches the part as uploaded
	frames: { [number]: CFrame },
}

export type Animation = { [string]: Track }

local KeyframeData = {}

-- Blender is Z-up and Roblox is Y-up. Both are right-handed, so (x, y, z) -> (x, z, -y)
local function ToRobloxAxes(x: number, y: number, z: number): (number, number, number)
	return x, z, -y
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
	local animation: Animation = {}

	for name, keyframes in raw do
		local frames: { [number]: CFrame } = {}
		local firstFrame = math.huge

		for frameKey, keyframe in keyframes do
			-- JSON object keys are always strings
			local frame = tonumber(frameKey) :: number
			frames[frame] = KeyframeData.ToCFrame(keyframe)
			firstFrame = math.min(firstFrame, frame)
		end

		animation[name] = {
			rest = frames[firstFrame],
			frames = frames,
		}
	end

	return animation
end

-- Maps each part's name to the Motor6D that drives it
function KeyframeData.GetMotors(assembly: Instance): { [string]: Motor6D }
	local motors: { [string]: Motor6D } = {}

	for _, descendant in assembly:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			motors[descendant.Part1.Name] = descendant
		end
	end

	return motors
end

-- Poses every part that has a keyframe on this frame. Transforms are relative to
-- each part's rest pose, which assumes the skeleton sets C0 to the part's rest
-- offset from Part0 and leaves C1 as identity.
function KeyframeData.ApplyFrame(motors: { [string]: Motor6D }, animation: Animation, frame: number)
	for name, track in animation do
		local motor = motors[name]
		local pose = track.frames[frame]

		if motor and pose then
			motor.Transform = track.rest:Inverse() * pose
		end
	end
end

return KeyframeData
