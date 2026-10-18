--!strict
--!optimize 2
--!native

const HttpService = game:GetService("HttpService")
const ReflectionService = game:GetService("ReflectionService")
const CollectionService = game:GetService("CollectionService")

const Shared = require(script.Shared)
const Stack = require(script.Stack)
const TagHandlers = require(script.TagHandler)
const Types = require(script.Types)
const GetPseudoElements = require(script.GetPseudoElements)


export type DocumentSource = {
	markup: string,
	functions: {
		[string]: Types.InjectableFunction 
	}
}

local Parser = {}

const connections: { [string]: RBXScriptConnection } = {}

const RichTextTags = {
	b = true,
	i = true,
	u = true,
	s = true,
	font = true,
	stroke = true,
	uppercase = true,
	uc = true,
	smallcaps = true,
	sc = true,
	mark = true,
}

local function ReverseInPlace<T>(array: { T }): ()
	local i, j = 1, #array

	while i < j do
		array[i], array[j] = array[j], array[i]
		i += 1
		j -= 1
	end
end

const function ScanForClosingTag(lines: Stack.Stack<string>, tag: string): string?
	const openPattern = `<{tag}%f[%s>]`
	const closePattern = `</{tag}>`
	const contentPattern = `^%s*<{tag}%f[%s>][^>]*>(.*)</{tag}>$`

	local statement = ""
	local depth = 0

	repeat
		if #lines == 0 then
			return nil
		end

		const nextLine = lines:pop()
		
		statement ..= "\n" .. nextLine

		for _ in nextLine:gmatch(openPattern) do
			depth += 1
		end

		for _ in nextLine:gmatch(closePattern) do
			depth -= 1
		end
	until depth == 0

	const content = statement:match(contentPattern)

	return content
end

function Parser.SplitStringArray(content: string, storageOperator: string?)
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

function Parser.ReconstructRichText(tokens: { Types.Token }, startCursor: number, tag: string): (string, number)
	const parts: { string } = {}
	local depth = 0
	local cursor = startCursor
	
	while tokens[cursor].type ~= "EOF" do
		--it()
		const token = tokens[cursor]

		if token.type == "TagOpen" then
			table.insert(parts, `<{token.tag} {token.attributes}>`)
			if token.tag == tag then
				depth += 1
			end
		elseif token.type == "TagSelfClose" then
			table.insert(parts, `<{token.tag} {token.attributes}/>`)
		elseif token.type == "TagClose" then
			table.insert(parts, `</{token.tag}>`)
			if token.tag == tag then
				depth -= 1
				if depth == 0 then
					return table.concat(parts), cursor + 1
				end
			end
		elseif token.type == "Text" and token.value then
			table.insert(parts, token.value)
		end

		cursor += 1
	end

	return table.concat(parts), cursor
end

function Parser.Tokenize(source: string)
	task.wait()
	-- Find all image ids within the source string and attempt to cache their dimensions
	
	const tokens: { Types.Token } = {}
	local i = 1
	local length = #source
	
	while i <= length do
		--it()
		local character = source:sub(i, i)
		--print(source:sub(math.max(i - 5, 0), math.min(i + 5, #source)), character)
		
		if character == "<" and source:sub(i, i + 3) == "<!--" then
			local commentEnd = source:find("-->", i, true) or (length + 3)
			--print(source:sub(math.max(i, 0), math.min(commentEnd + 3, #source)), character)
			i = commentEnd + 3
			continue
		end
		
		if character == "<" then
			local _, closeTagEnd, closeTag = source:find("^</([%w]-)%s*>", i)
			
			if closeTagEnd and closeTag then
				table.insert(tokens, { 
					type = "TagClose" :: Types.TokenType, 
					tag = closeTag,
					position = i 
				})
				
				i = closeTagEnd + 1
				continue
			end
			
			local selfTag, selfAttrs, selfEnd = source:match("^<([%w]+)%s*([^>]-)/>()", i)
			
			if selfTag and selfEnd then
				table.insert(tokens, {
					type = "TagSelfClose" :: Types.TokenType, 
					tag = selfTag, 
					attributes = selfAttrs, 
					position = i 
				})
				
				i = selfEnd
				continue
			end
			
			local openTag, openAttrs, openEnd = source:match("^<([%w]+)%s*([^>]-)>()", i)

			if openTag and openEnd then
				table.insert(tokens, {
					type = "TagOpen" :: Types.TokenType, 
					tag = openTag, 
					attributes = openAttrs, 
					position = i 
				})

				i = openEnd
				continue
			end
			
			error("m")
		end
		
		local textEnd = source:find("<", i, true) or length + 1 
		--local commentStart = source:find("<!%-%-", i)

		--if commentStart and commentStart < textEnd then
		--	textEnd = commentStart
		--end

		local text = source:sub(i, textEnd - 1)

		if text:match("%S") then
			table.insert(tokens, {
				type = "Text" :: Types.TokenType,
				value = text,
				position = i,
			})
		end

		i = textEnd
	end
	
	table.insert(tokens, { 
		type = "EOF" :: Types.TokenType, 
		position = i 
	})
	
	return tokens
end

function Parser.AssignNodePointers(node: Types.Node, pointers: Types.Pointers)
	for name, attribute in node.attributes do
		if name:lower() == "classes" and typeof(attribute) == "table" then
			for _, class in attribute :: { string } do
				if not pointers.Class[class] then
					pointers.Class[class] = {}
				end

				table.insert(pointers.Class[class], node.uniqueId)
			end
		elseif name:lower() == "id" and typeof(attribute) == "string" then
			pointers.Id[attribute] = node.uniqueId
		end
	end
end

function Parser.ParseTokens(tokens: { Types.Token }, pointers: Types.Pointers): ( { [string]: Types.Node }, number )
	local root: { string } = {}
	
	local nodes: { [string]: Types.Node } = {}
	local nodeCount = 0
	-- The root entry has no node, so node is optional
	local stack: Stack.Stack<{ node: Types.Node?, children: { string } }>
		= Stack.new({ { node = nil, children = root } } :: { { node: Types.Node?, children: { string } } })

	local cursor = 1
	local order = 0

	while tokens[cursor].type ~= "EOF" do
		--task.wait()
		local token = tokens[cursor]
		-- Read once per token so the type checker can narrow away nil
		const parent = stack:peek().node

		if token.type == "Text" and token.value and parent then
			table.insert(parent.textBlob, token.value)
		elseif token.type == "TagSelfClose" and token.tag and token.attributes then
			local node: Types.Node

			if not Shared.TagInstanceMap[token.tag] and TagHandlers[({(token.tag):gsub("[^%a]+", "")})[1]] then 
				node = TagHandlers[({(token.tag):gsub("[^%a]+", "")})[1]](token)
			elseif Shared.TagInstanceMap[token.tag] then
				node = TagHandlers.primitive(token)
			end
			
			if not node then
				error("Failed to create node")
			end
			
			node.order = order
			node.parentId = parent and parent.uniqueId

			order += 1

			Parser.AssignNodePointers(node, pointers)
			
			table.insert(stack:peek().children, node.uniqueId)
			nodes[node.uniqueId] = node
			nodeCount += 1

		elseif token.type == "TagOpen" and token.tag and token.attributes then
			if RichTextTags[token.tag] then
				const rawText, nextCursor = Parser.ReconstructRichText(tokens, cursor, token.tag)

				if parent then
					table.insert(parent.textBlob, rawText)
				end

				cursor = nextCursor
				continue
			end
			
			local node: Types.Node
			
			if not Shared.TagInstanceMap[token.tag] and TagHandlers[({(token.tag):gsub("[^%a]+", "")})[1]] then 
				node = TagHandlers[({(token.tag):gsub("[^%a]+", "")})[1]](token)
			elseif Shared.TagInstanceMap[token.tag] then
				node = TagHandlers.primitive(token)
			end
			
			if not node then
				error("Failed to create node")
			end
			
			node.order = order
			node.parentId = parent and parent.uniqueId

			order += 1

			table.insert(stack:peek().children, node.uniqueId)
			nodes[node.uniqueId] = node
			nodeCount += 1

			Parser.AssignNodePointers(node, pointers)
			
			stack:push({ node = node, children = node.childIds })
		elseif token.type == "TagClose" then
			if not parent or parent.tag ~= token.tag then
				error(`Mismatched closing tag: expected </{parent and parent.tag}>, got </{token.tag}>`)
			end
			
			stack:pop()
		end
		
		cursor += 1
	end
	
	return nodes, nodeCount
end

function Parser.ParseDocument(documentSource: DocumentSource): Types.Document
	const pointers: Types.Pointers = {
		Class = {},
		Id = {},
		NodeIds = {}
	}
	
	local t = os.clock()
	const tokens = Parser.Tokenize(documentSource.markup)
	
	t = os.clock()
	const document, nodeCount = Parser.ParseTokens(tokens, pointers)
	
	return {
		Destroying = Instance.new("BindableEvent"),
		Nodes = document, 
		Pointers = pointers,
		NodeCount = nodeCount,
		Functions = table.clone(documentSource.functions)
	} :: Types.Document
end

--[[
export type NodeData = {
	tag: string, 
	childIds: { string }?, 
	attributes: { [string]: any }?, 
	eventHandlers: { [string]: InjectableFunction }?,
	innerText: string? 
}
]]
function Parser.CreateDocumentNode(nodeData: Types.NodeData, document: Types.Document): Types.Node
	const eventHandlers: { [string]: string } = {}
	
	if nodeData.eventHandlers then
		for eventName, func in nodeData.eventHandlers do
			const functionKey = Shared.GenerateRandomChars(4, document)
			eventHandlers[eventName] = functionKey
			document.Functions[functionKey] = func
		end		
	end
	
	const node: Types.Node = {
		uniqueId = Shared.GenerateRandomChars(5, document), 
		tag = nodeData.tag,
		classname = Shared.TagInstanceMap[nodeData.tag],
		attributes = nodeData.attributes or {},
		eventHandlers = eventHandlers, 
		childIds = nodeData.childIds or {},
		innerText = nodeData.innerText or "", 
		textBlob = {},
		parentId = nil, 
		connections = {},
	}
	
	document.Nodes[node.uniqueId] = node
	
	return node
end

local function RenderNode(node: Types.Node, document: Types.Document?): GuiObject 
	-- Stays nil if no prefab matches; checked below
	local object: GuiObject?

	if node.tag == "prefab" then
		for _, prefab in CollectionService:GetTagged("prefab") do
			const prefabName = node.attributes["prefab-name"]
			
			if typeof(prefabName) == "string" and string.lower(prefabName :: string) == prefab.Name:lower() and prefab:IsA("GuiObject") then
				const clone = prefab:Clone() :: GuiObject
				object = clone
				node.classname = clone.ClassName
				
				break
			end
		end
		
		if not object then
			error(`Unknown prefab: { node.attributes["prefab-name"] }`)
		end
	else
		object = Instance.new(node.classname) :: GuiObject
	end
	
	if not object then
		error(`Failed to create object of type with tag: { node.classname }, { node.tag }`)
	end

	;(object :: GuiObject).LayoutOrder = node.order or -1
	
	if not Shared.ReflectionServiceCache[node.classname] then
		error(`Invalid ClassName: {node.classname}`)
	end

	--Pull up properties for the object classname and apply any inline attributes to the object if applicable
	for _, property in Shared.ReflectionServiceCache[node.classname].properties do
		local propertyName = property.Name:lower()
		if not propertyName:match("%((.-)%)") and node.attributes[propertyName] and property.Permits.Write then
			if propertyName == "styles" or propertyName == "classes" then
				continue
			end

			--if property.Type.ScriptType ~= "number" and property.Type.ScriptType ~= "boolean" and property.Type.ScriptType ~= "string" then
			--	error(`Invalid property. Expected {property.Type.ScriptType}, got {typeof(node.attributes[propertyName])}, {node.attributes[propertyName]} for {property.Name}`)
			--end
			
			if property.Type.ScriptType == "Color3" then
				(object :: any)[property.Name] = Color3.fromHex(node.attributes[propertyName])
			else
				(object :: any)[property.Name] = node.attributes[propertyName]
			end
		end
	end
	
	if document then
		for _, event in Shared.ReflectionServiceCache[node.classname].events do
			local eventName = event.Name:lower()
			
			--print(eventName, node.attributes[`({eventName})`])
			
			if node.eventHandlers[`{eventName}`] then
				--if eventName == "styles" or eventName == "classes" then
				--	continue
				--end

				--if property.Type.ScriptType ~= "number" and property.Type.ScriptType ~= "boolean" and property.Type.ScriptType ~= "string" then
				--	error(`Invalid property. Expected {property.Type.ScriptType}, got {typeof(node.attributes[propertyName])}, {node.attributes[propertyName]} for {property.Name}`)
				--end

				node.connections[eventName:lower()] = (object :: any)[event.Name]:Connect(function(...: any)
					document.Functions[node.eventHandlers[eventName:lower()]](node, document, ...) 
				end) :: RBXScriptConnection
			end 
		end
	end
	
	if node.attributes["image"] and node.attributes["fit"] == "full" and object:IsA("ImageLabel") then
		local cachedSize = Shared.CachedImageSizes[node.attributes["image"]]
		
		if node.attributes["ratio"] then
			if typeof(node.attributes["ratio"]) ~= "number" then
				error("Invalid aspect ratio value")
			end
			
			local constraint = Instance.new("UIAspectRatioConstraint")
			constraint.AspectRatio = node.attributes["ratio"]
			constraint.AspectType = Enum.AspectType.FitWithinMaxSize
			constraint.DominantAxis = Enum.DominantAxis.Width
			constraint.Parent = object
			
			object.Size = UDim2.fromScale(1, 10)
		elseif cachedSize and cachedSize.X / cachedSize.Y ~= 1 then
			local constraint = Instance.new("UIAspectRatioConstraint")
			constraint.AspectRatio = cachedSize.X / cachedSize.Y
			constraint.AspectType = Enum.AspectType.FitWithinMaxSize
			constraint.DominantAxis = Enum.DominantAxis.Width
			constraint.Parent = object
			
			object.Size = UDim2.fromScale(1, 10)
		else
			local constraint = Instance.new("UIFlexItem")
			constraint.FlexMode = Enum.UIFlexMode.Fill
			constraint.Parent = object
			
			object.Size = UDim2.fromScale(1, 1)
			object.ScaleType = Enum.ScaleType.Fit
			
			object.SizeConstraint = Enum.SizeConstraint.RelativeXX
		end
	end
	
	--if object:IsA("ScrollingFrame") then
	--	object.CanvasSize = UDim2.new(1, 0, 1, 0)
	--end
	
	const styles = node.attributes.styles :: ({ string } | string)?
	
	if styles then
		if typeof(styles) == "table" then
			for _, style in styles do
				CollectionService:AddTag(object, (style :: any):match("^%s*(.-)%s*$"))
			end
		elseif typeof(styles) == "string" then
			CollectionService:AddTag(object, (styles :: any):match("^%s*(.-)%s*$"))
		end
	end
	
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		const text: string? = if #node.textBlob > 0
			then (table.concat(node.textBlob, " "):match("^%s*(.-)%s*$") or ""):gsub("\t+", "") :: string
			elseif node.innerText then node.innerText:match("^%s*(.-)%s*$") :: string
			else nil

		-- Luau can't assign a property through a union type, so set it through each class
		if text then
			if object:IsA("TextLabel") then
				(object :: TextLabel).Text = text
			else
				(object :: TextButton).Text = text
			end
		end
	elseif object:IsA("ScrollingFrame") then
		--node.connections[""]
	end
	
	CollectionService:AddTag(object, `rbmluniqueelement_{node.uniqueId}`)
	node.element = object
	
	CollectionService:AddTag(object, node.tag)

	return object
end

function Parser.GetObjectsByClass(class: string, document: Types.Document): { Types.Node }
	const objects: { Types.Node } = {}

	if document.Pointers.Class[class] then
		for id, elementId in document.Pointers.Class[class] do	
			const node = document.Nodes[elementId]

			if not node then
				continue
			end

			table.insert(objects, node)
		end
	end

	return objects
end

function Parser.GetObjectById(id: string, document: Types.Document): Types.Node?
	return document.Pointers.Id[id] and document.Nodes[document.Pointers.Id[id]] or nil
end

function Parser.GetNodeFromElement(element: Instance, document: Types.Document): Types.Node?
	-- RenderNode tags every element with its node's uniqueId
	for _, tag in element:GetTags() do
		const uniqueId = tag:match("^rbmluniqueelement_(.+)$")

		if uniqueId then
			return document.Nodes[uniqueId]
		end
	end

	return nil
end

function RecursiveClear(t: any)
	if typeof(t) == "table" then
		for _, v in t do
			if typeof(v) == "table" then
				RecursiveClear(v)
			end
		end

		table.clear(t)
	else 
		t = nil
	end
end

function ClearNode(node: Types.Node, document: Types.Document): boolean
	local connectionCount = 0
	
	if node.connections then
		for _, connection in node.connections do
			connectionCount += 1
			connection:Disconnect()
		end
	end
	
	if node.eventHandlers then
		for n, v in node.eventHandlers do
			if document.Functions[v] then
				document.Functions[v] = nil
			end
		end
	end
	
	--warn(`Cleaned up {connectionCount} connections`)
	
	if node.element then
		node.element:Destroy()
	end
	
	if node.childIds then
		for _, childId in node.childIds do
			if document.Nodes[childId] then
				--print("CLEARING CHILD: ", childId)
				ClearNode(document.Nodes[childId], document)
			end
		end
	end
	
	if document.Pointers then
		for _, class in document.Pointers.Class do
			const nodeIndex = table.find(class, node.uniqueId)

			if nodeIndex then
				table.remove(class, nodeIndex)
			end
		end

		for attribute, id in document.Pointers.Id do
			if id == node.uniqueId then
				document.Pointers.Id[attribute] = nil
			end
		end
	end

	if node.parentId and document.Nodes[node.parentId] and document.Nodes[node.parentId].childIds then
		const childIndex = table.find(document.Nodes[node.parentId].childIds, node.uniqueId)

		if childIndex then
			table.remove(document.Nodes[node.parentId].childIds, childIndex)
		end
	end
	
	if Shared.UniqueStrings and node.uniqueId and Shared.UniqueStrings[node.uniqueId] then
		Shared.UniqueStrings[node.uniqueId] = nil
	end

	RecursiveClear(node)
	
	if document and document.NodeCount and document.Nodes then
		document.NodeCount -= 1
	
		if document.Nodes[node.uniqueId] then
			document.Nodes[node.uniqueId] = nil
		end
		
		--if document.NodeCount == 0 and document.Destroying then
		--	document.Destroying:Fire()
		--	document.Destroying:Destroy()
		--	RecursiveClear(document)
		--end
	end
	
	return true
end

function Parser.CreateCleanupConnection(node: Types.Node, nodeElement: GuiObject, document: Types.Document)
	if node.connections["cleanup"] then
		node.connections["cleanup"]:Disconnect()
	end

	node.connections["cleanup"] = nodeElement.Destroying:Once(function()
		ClearNode(node, document)
	end)
end

function Parser.InsertAt(object: Types.Node | string, newObject: Types.Node, offset: number, document: Types.Document, parentId: string?) 
	if typeof(object) == "string" then
		object = document.Nodes[object]
	end
	
	assert(typeof(object) == "table" and typeof(newObject) == "table")
	
	newObject.order = object.order and object.order + offset
	newObject.parentId = parentId or object.parentId

	table.insert(object.childIds, newObject.uniqueId)

	if not document.Nodes[newObject.uniqueId] then
		Parser.AssignNodePointers(newObject, document.Pointers)
		document.Nodes[newObject.uniqueId] = newObject
	end

	const uiElement = RenderNode(newObject, document)
	Parser.CreateCleanupConnection(newObject, uiElement, document)

	if newObject.element and newObject.parentId and document.Nodes[newObject.parentId] and document.Nodes[newObject.parentId].element then
		newObject.element.Parent = document.Nodes[newObject.parentId].element
	end

	local siblings = newObject.parentId and document.Nodes[newObject.parentId] and document.Nodes[newObject.parentId].childIds 

	if siblings then
		for _, siblingId in siblings do
			local sibling = document.Nodes[siblingId]
			if sibling and sibling.order and sibling ~= newObject and sibling.order >= (newObject.order :: number) then
				sibling.order += 1
				if sibling.element then
					sibling.element.LayoutOrder = sibling.order
				end
			end
		end
	end
end

export type Page = {
	rendered: { GuiObject },
	GetObjectsByClass: (class: string) -> { Types.Node },
	GetObjectById: (id: string) -> Types.Node?,
	GetNodeFromElement: (element: Instance) -> Types.Node?,
	GetObjectsByTag: (tag: string) -> { Types.Node },
	InsertBefore: (object: Types.Node | string, newObject: Types.Node) -> (),
	InsertAfter: (object: Types.Node | string, newObject: Types.Node) -> (),
	InsertStart: (object: Types.Node | string, newObject: Types.Node) -> (),
	InsertEnd: (object: Types.Node | string, newObject: Types.Node) -> (),
	DeleteObject: (object: Types.Node | string) -> (),
	Destroy: () -> (),
}

function Parser.Render(document: Types.Document): Page
	const renderedObjects: { GuiObject } = {}
	
	local page; page = {
		rendered = renderedObjects,
		GetObjectsByClass = function(class: string): { Types.Node }
			return Parser.GetObjectsByClass(class, document)
		end,
		GetObjectById = function(id: string): Types.Node?
			return Parser.GetObjectById(id, document)
		end,
		GetNodeFromElement = function(element: Instance): Types.Node?
			return Parser.GetNodeFromElement(element, document)
		end,
		GetObjectsByTag = function(tag: string): { Types.Node }
			const nodes: { Types.Node } = {}
			
			for _, node in document.Nodes do
				if node.tag == tag then
					table.insert(nodes, node)
				end
			end
			
			return nodes
		end,
		InsertBefore = function(object: Types.Node | string, newObject: Types.Node) 
			Parser.InsertAt(object, newObject, 0, document)
		end,
		InsertAfter = function(object: Types.Node | string, newObject: Types.Node) 
			Parser.InsertAt(object, newObject, 1, document)
		end,
		InsertStart = function(object: Types.Node | string, newObject: Types.Node)
			if typeof(object) == "string" then
				object = document.Nodes[object]
			end
			
			if typeof(object) == "table" then
				newObject.parentId = object.uniqueId
				
				if object.childIds[1] then
					local firstChild = document.Nodes[object.childIds[1]]
					Parser.InsertAt(firstChild, newObject, 0, document, object.uniqueId)
				else
					Parser.InsertAt(object, newObject, 1, document, object.uniqueId)
				end
			end
		end,
		InsertEnd = function(object: Types.Node | string, newObject: Types.Node) 
			if typeof(object) == "string" then
				object = document.Nodes[object]
			end

			if typeof(object) == "table" then
				newObject.parentId = object.uniqueId

				if #object.childIds > 0 and object.childIds[#object.childIds] then
					local firstChild = document.Nodes[object.childIds[#object.childIds]]
					Parser.InsertAt(firstChild, newObject, 1, document, object.uniqueId)
				else
					Parser.InsertAt(object, newObject, 1, document, object.uniqueId)
				end
			end
		end,
		DeleteObject = function(object: Types.Node | string)
			if typeof(object) == "string" then
				object = document.Nodes[object]
			end
			
			if Shared.UniqueStrings[(object :: Types.Node).uniqueId] then
				Shared.UniqueStrings[(object :: Types.Node).uniqueId] = nil
			end
			
			assert(typeof(object) == "table")
			
			ClearNode(object, document)
		end,
		Destroy = function()
			for _, node in document.Nodes do
				ClearNode(node, document)
			end
			
			RecursiveClear(document)
			RecursiveClear(page)
		end,
	} :: Page
	
	if not document.Nodes then
		return page
	end
	
	for _, node in document.Nodes do	
		const object = RenderNode(node, document)
		Parser.CreateCleanupConnection(node, object, document)
		
		if not node.parentId then
			table.insert(renderedObjects, object)
		end
	end
	
	for id, node in document.Nodes do
		if node.element and node.parentId and document.Nodes[node.parentId] and document.Nodes[node.parentId].element then
			node.element.Parent = document.Nodes[node.parentId].element
		end
	end
	
	return page
end

return Parser