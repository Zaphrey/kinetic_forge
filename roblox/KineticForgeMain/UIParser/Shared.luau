--!strict
--!optimize 2
--!native

const AssetService = game:GetService("AssetService")
const ReflectionService = game:GetService("ReflectionService")
const HttpService = game:GetService("HttpService")
const Stack = require(script.Parent.Stack)
const Types = require(script.Parent.Types)

const Shared = {}

Shared.Patterns = {
	OpeningTag = "<([^%s/>]+)%s*([^>]*)>",
	VoidTag = "<([^%s/>]+)%s*([^>]*)/>",
	ClosingTag = "<(/[^%s>]+)[^>]*>",
	Statement = "<%s(.-)>(.-)</%s>",
	ArrayAttributes = `([%w-]+)%s*=%s*"(%[.+%])"`,
	DictionaryAttributes = '([%w-]+)%s*=%s*"({.+})"',
	PlainAttributes = `([%w-]+)%s*=%s*"([^"]*)"`,
	FunctionAttributes = `%(([%w-]+)%)%s*=%s*"([^"]*)"`,
}

Shared.TagInstanceMap = (function(): { [string]: string }
	const map: { [string]: string } = {}

	const classes = ReflectionService:GetClasses({ IsA = "GuiObject", ExcludeDisplay = true })

	for _, v in classes do
		if v.Subclasses then
			continue
		end

		map[v.Name:lower()] = v.Name
	end

	return table.freeze(map)
end)() :: { [string]: string }

Shared.ReflectionServiceCache = (function()
	const reflectionCache: { 
		[string]: {
			properties: { ReflectedProperty },
			events: { ReflectedEvent },
			methods: { ReflectedMethod }
		}	
	} = {}
	
	for _, className in Shared.TagInstanceMap do
		reflectionCache[className] = {
			properties = ReflectionService:GetPropertiesOfClass(className),
			events = ReflectionService:GetEventsOfClass(className),
			methods = ReflectionService:GetMethodsOfClass(className)
		}
	end
	
	return reflectionCache
end)()

const CachedImageSizes: { [string]: Vector2 } = {}
Shared.CachedImageSizes = CachedImageSizes

local function GetImageSize(assetId: string | number): Vector2?
	if typeof(assetId) == "string" and assetId ~= nil then
		assetId = tonumber(({ assetId:match("%d+") })[1]) or 0
	end

	local success, editableImage = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromAssetId(assetId :: number))
	end)

	if success and editableImage then
		return editableImage.Size
	else
		print(editableImage)
	end

	return nil
end

function Shared.CacheSourceImageSizes(source: string)
	for match in source:gmatch(`image="(.-)"`) do
		print(match, Shared.CachedImageSizes[tostring(match)])
		if Shared.CachedImageSizes[tostring(match)] then
			continue
		end
		
		local imageSize = GetImageSize(match)
		
		if imageSize then
			Shared.CachedImageSizes[tostring(match)] = imageSize
		end
	end
end


Shared.UniqueStrings = {} :: {
	[string]: boolean
}

function Shared.GenerateRandomChars(length: number, document: Types.Document): string
	local str = ""

	repeat
		--task.wait()
		str = ""

		for i = 1, length do
			const randomNum = math.random(1, 3)

			str ..= randomNum == 1 and string.char(math.random(48, 57)) or randomNum == 2 and string.char(math.random(65, 90)) or string.char(math.random(97, 122))
		end
		
		--print(document.Nodes, Shared.UniqueStrings)
	until (document == nil or not document.Nodes[str]) and not Shared.UniqueStrings[str]
 
	Shared.UniqueStrings[str] = true

	return str
end

function Shared.SplitStringArray(content: string, storageOperator: string?)
	--[[
	
	Scan a string from left to right to check if any of the strings within the array contain a comma.
	
	]]

	const quotes: Stack.Stack<string> = Stack.new({} :: { string })
	const parts: { string } = {}

	const toBuild: { string } = {}

	for char in string.gmatch(content, ".") do
		if #quotes == 0 then -- Outside string
			if char == "`" or (char == '"' and storageOperator ~= "{") or char == "'" then
				quotes:push(char)
				continue
			elseif char == "," then
				-- Concat current toBuild content together and push it to parts
				local concatedString = table.concat(toBuild)

				if storageOperator == "{" or tonumber(concatedString) then
					table.insert(parts, `{concatedString}`)
				else
					table.insert(parts, `"{concatedString:gsub("^%s+", "")}"`)
				end

				table.clear(toBuild)

				--print(parts)
				continue
			end
		elseif #quotes > 0 then -- Inside string
			if quotes:peek() == char then
				quotes:pop()
				continue
			end
		end

		-- Ignore leading whitespace
		if #toBuild == 0 and char == " " then
			continue
		end

		table.insert(toBuild, char)

		--print(toBuild)
	end

	if #toBuild > 0 then
		local concatedString = table.concat(toBuild)

		if storageOperator == "{" or tonumber(concatedString) then
			table.insert(parts, `{concatedString}`)
		else
			table.insert(parts, `"{concatedString:gsub("^%s+", "")}"`)
		end

		table.clear(toBuild)
	end

	return storageOperator == "[" and `[{table.concat(parts, ", ")}]` or storageOperator == "{" and `\{{table.concat(parts, ", ")}\}` or `{table.concat(parts, ", ")}`
end

-- Basic decoding, only supports primitive types
function Shared.ParseAttribute(value: string): any
	const success, decoded = pcall(function(): any
		const storageOperator, innerContent = value:match("([%[{])(.-)[%]}]")

		if not innerContent then
			error("No matches")
		end

		const formattedContent = Shared.SplitStringArray(innerContent, storageOperator)
		--print(formattedContent)
		const decoded = HttpService:JSONDecode(formattedContent)

		return decoded
	end)

	if success then
		return decoded
	end

	const num = tonumber(value)

	if num then
		return num
	end

	return value
end

function Shared.ParseTagAttributes(attributes: string): ({ [string]: any }, { [string]: any })
	const parsedAttributes: { [string]: any } = {}
	const eventHandlers: { [string]: any } = {}

	for attribute, value in attributes:gmatch(Shared.Patterns.ArrayAttributes) do
		--print("ARRAY ATTRIBUTE", value)
		parsedAttributes[attribute] = Shared.ParseAttribute(value)
	end

	attributes = attributes:gsub(Shared.Patterns.ArrayAttributes, "")
	--print(attributes)

	for attribute, value in attributes:gmatch(Shared.Patterns.DictionaryAttributes) do
		--print("DICT ATTRIBUTE", value)
		parsedAttributes[attribute] = Shared.ParseAttribute(value)
	end

	attributes = attributes:gsub(Shared.Patterns.DictionaryAttributes, "")
	--print(attributes)

	for attribute, value in attributes:gmatch(Shared.Patterns.PlainAttributes) do
		--print("PLAIN ATTRIBUTE", value)
		parsedAttributes[attribute] = Shared.ParseAttribute(value)
	end

	attributes = attributes:gsub(Shared.Patterns.PlainAttributes, "")
	--print(attributes)

	for attribute, value in attributes:gmatch(Shared.Patterns.FunctionAttributes) do
		--print("PLAIN ATTRIBUTE", value)
		eventHandlers[attribute] = Shared.ParseAttribute(value)
	end

	attributes = attributes:gsub(Shared.Patterns.FunctionAttributes, "")
	--print(attributes)

	return parsedAttributes, eventHandlers
end


return Shared