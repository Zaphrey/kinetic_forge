--!strict
-- Types shared across the plugin. The UI parser's own types are in UIParser/Types.

-- A model rigged by Skeleton.Generate, which names its controller and animator by class
export type Assembly = Model & {
	AnimationController: AnimationController & {
		Animator: Animator,
	},
}

return {}
