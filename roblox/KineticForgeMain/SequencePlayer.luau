--!strict
--!native
--optimize 2

const AnimationClipProvider = game:GetService("AnimationClipProvider")
const KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local Trove = require("./Trove")
local Types = require("./Types")

local Player = {}

-- Loads the sequence as a track on the assembly's Animator, inside a new Trove that's itself
-- inside the given one. Cleaning either Trove (e.g. on reload) puts the pieces back and removes
-- the track.
local function LoadTrack(sequence: KeyframeSequence, assembly: Types.Assembly, trove: Trove.Trove): (AnimationTrack, Trove.Trove)
    const id = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
    const animation = Instance.new("Animation")
    animation.AnimationId = id
    const animator = assembly.AnimationController.Animator
    const track = animator:LoadAnimation(animation)

    const animTrove = trove:Extend()
    animTrove:Add(animation)
    animTrove:Add(function()
        -- In Edit mode, stopping a track leaves the pieces wherever it last posed them, and only
        -- stepping the Animator moves them. So show the first frame, the rest pose, before stopping.
        -- pcall, since the rig may have been deleted by the time this runs.
        pcall(function()
            if not track.IsPlaying then
                track:Play(0)
            end
            track.TimePosition = 0
            track:AdjustSpeed(0)
            animator:StepAnimations(0)
        end)

        -- Stop(0) skips the fade-out. Nothing steps it to the end in Edit mode, so a fading track
        -- would keep blending into whatever plays next.
        track:Stop(0)
    end)

    return track, animTrove
end

-- Poses the assembly on the sequence's first frame and holds it there. Poses are relative to each
-- piece's first-frame position, so this puts every piece back where the rig was generated.
function Player.ShowFirstFrame(sequence: KeyframeSequence, assembly: Types.Assembly, trove: Trove.Trove): Trove.Trove
    const track, animTrove = LoadTrack(sequence, assembly, trove)

    track:Play(0)
    track.TimePosition = 0
    track:AdjustSpeed(0)

    -- Pieces only move in Edit mode when the Animator is stepped
    assembly.AnimationController.Animator:StepAnimations(0)

    return animTrove
end

function Player.LoadSequence(sequence: KeyframeSequence, assembly: Types.Assembly, trove: Trove.Trove): Trove.Trove
    const animationClip, animTrove = LoadTrack(sequence, assembly, trove)
    -- animationClip.Looped = false
    animationClip.Looped = true

    animationClip:Play()

    animTrove:Add(RunService.RenderStepped:Connect(function(dt)
        assembly.AnimationController.Animator:StepAnimations(dt) 

        if not animationClip.Looped and animationClip.TimePosition >= animationClip.Length then 
            animTrove:Clean()
        end   
    end))   

    return animTrove 
end 
 
return Player 