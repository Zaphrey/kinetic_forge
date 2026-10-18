--!strict
--!optimize 2
--!native

local Types = require(script.Parent.UIParser.Types) 
local Shared = require(script.Parent.UIParser.Shared)
local Styles = require(script.Styles) 

const toInject: { [string]: (...any) -> (...any) } = {}

const toReplace: { [string]: string } = {
	UPDATEVERSION = "v67",
	PATCHDATETEXT = "PATCH NOTES - August 20th, 2026",
	HEROIMAGE = "rbxassetid://10582091635",
	LOGOIMAGE = "rbxassetid://94470596229835"
}

const functions: { [string]: Types.InjectableFunction } = {
	onclick = function(object, document)
		if object.element then
			const canvas = object.element:FindFirstAncestorWhichIsA("CanvasGroup")

			if canvas then
				canvas:Destroy() 
			end
			
			task.wait()
		end 
	end	
}

local markup = [[
<scrollingframe id="main-container" styles="[main-container, container, list-vertical]">
	<frame styles="[container, list-vertical, fill-x]">
		<textlabel>
			Automatically generate a skeleton for any rigid body assembly
		</textlabel>
		<textlabel id="detected-assemblies">
			Detected assemblies: 0
		</textlabel>
		<textbutton id="generate-skeleton-button" styles="[no-flex, disabled]">
			Generate Skeleton
		</textbutton>
		<textbutton id="reset-pose-button" styles="[no-flex, disabled]">
			Reset Pose
		</textbutton>
	</frame>
	<frame styles="[container, list-vertical, fill-x]">
		<textbox id="data-box" styles="[container]" text="", placeholdertext="Paste Keyframe Data Here"/>
		<textbutton id="import-keyframes-button" styles="[no-flex, disabled]">
			Import Keyframes
		</textbutton>
	</frame>
</scrollingframe>
]]

for replace, with in toReplace do
	markup = markup:gsub(`%%{replace}%%`, with)
end

return {
	markup = markup,
	functions = functions,
	styles = Styles
}
