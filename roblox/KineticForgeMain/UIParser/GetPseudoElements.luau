--!strict
--!optimize 2
--!native

const ReflectionService = game:GetService("ReflectionService")
const PSEUDO_ELEMENT_SUPERCLASS = "UIBase"

export type PseudoElementEntry = {
	[string]: boolean
}

export type PseudoElementDictionary = {
	[string]: PseudoElementEntry
}

const pseudoElements: PseudoElementDictionary = {}
const ignoreSelectors: { [string]: boolean? } = { [":hover"] = true, [":press"] = true, [":idle"] = true, [":noninteractable"] = true }
--const ignoreSelectors: { string } = {}

for _, class in ReflectionService:GetClasses({ IsA = PSEUDO_ELEMENT_SUPERCLASS }) do
	if class.Subclasses then
		continue
	end

	const properties: PseudoElementEntry = {}

	for _, property in ReflectionService:GetPropertiesOfClass(class.Name) do
		if property.Display and property.Display.DeprecationMessage then
			continue
		end
		
		if not (property.Permits.Read and property.Permits.Write) then
			continue
		end

		properties[property.Name] = true
	end

	pseudoElements[class.Name] = properties
	ignoreSelectors[`::{class.Name}`] = true
	--table.insert(ignoreSelectors, `::{class.Name}`)
end

const function GetPseudoElements(element: GuiObject): ({ [string]: boolean }, number)
	const elements: { [string]: boolean } = {}
	local count = 0
	
	for class, properties in pseudoElements do
		for property, _ in properties do
			
			const s, m = pcall(element.GetStyled, element, property, `::{class}`)
			
			if s and not elements[class] then
				elements[class] = true
				count += 1
				break
			end
		end
	end
	
	return elements, count
end

return GetPseudoElements