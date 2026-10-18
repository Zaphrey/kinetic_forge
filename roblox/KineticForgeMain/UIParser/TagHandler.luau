--!strict
--!optimize 2
--!native
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

const Shared = require(script.Parent.Shared)
const Types = require(script.Parent.Types)
 
const Handlers = {
	h = function(token: Types.Token, document: Types.Document)
		if not token.tag then
			error("Token tag not provided")
		end
		
		const attributes, eventHandlers = Shared.ParseTagAttributes(token.attributes or "")
		
		const node = {
			uniqueId = Shared.GenerateRandomChars(5, document), 
			tag = token.tag,
			classname = "TextLabel",
			attributes = attributes,
			eventHandlers = eventHandlers,
			innerText = "",
			textBlob = {},
			childIds = {},
			connections = {},
		} :: Types.Node
		
		--print(token.tag:match("%s*(h%d)%s*"), token.tag)
		
		if token.tag:match("%s*(h%d)%s*") then
			const styles = node.attributes.styles

			if styles then
				if typeof(styles) == "string" then
					node.attributes.styles = { styles }
				end

				table.insert(node.attributes.styles, token.tag)
				table.insert(node.attributes.styles, "heading")
			else
				node.attributes.styles = { token.tag, "heading" }
			end
		end 

		return node
	end,
	
	hr = function(token: Types.Token, document: Types.Document)
		if not token.tag then
			error("Token tag not provided")
		end
		
		const attributes, eventHandlers = Shared.ParseTagAttributes(token.attributes or "")

		const node = {
			uniqueId = Shared.GenerateRandomChars(5, document), 
			tag = token.tag,
			classname = "Frame",
			attributes = attributes,
			eventHandlers = eventHandlers,
			childIds = {},
			connections = {},
		} :: Types.Node

		const styles = node.attributes.styles

		if styles then
			if typeof(styles) == "string" then
				node.attributes.styles = { styles }
			end

			table.insert(node.attributes.styles, "hr")
		else
			node.attributes.styles = { token.tag, "hr" }
		end

		return node
	end,

	primitive = function(token: Types.Token, document: Types.Document)
		if not token.tag then
			error("Token tag not provided")
		end
		
		const attributes, eventHandlers = Shared.ParseTagAttributes(token.attributes or "")

		const node = {
			uniqueId = Shared.GenerateRandomChars(5, document),
			tag = token.tag,
			classname = Shared.TagInstanceMap[({(token.tag):gsub("[^%a]+", "")})[1]],
			attributes = attributes,
			eventHandlers = eventHandlers,
			innerText = "",
			textBlob = {},
			childIds = {},
			connections = {},
		} :: Types.Node

		return node
	end,
	
	prefab = function(token: Types.Token, document: Types.Document)
		if not token.tag then
			error("Token tag not provided")
		end
		
		const attributes, eventHandlers = Shared.ParseTagAttributes(token.attributes or "")
		
		const node = {
			uniqueId = Shared.GenerateRandomChars(5, document),
			tag = token.tag,
			classname = "prefab",
			attributes = attributes,
			eventHandlers = eventHandlers,
			innerText = "",
			textBlob = {},
			childIds = {},
			connections = {},
		} :: Types.Node

		return node
	end,
	
	root = function(token: Types.Token, document: Types.Document)
		if not token.tag then
			error("Token tag not provided")
		end

		const attributes, eventHandlers = Shared.ParseTagAttributes(token.attributes or "")

		const node = {
			uniqueId = Shared.GenerateRandomChars(5, document),
			tag = token.tag,
			classname = "ScrollingFrame",
			attributes = attributes,
			eventHandlers = eventHandlers,
			innerText = "",
			textBlob = {},
			childIds = {},
			connections = {},
		} :: Types.Node

		return node
	end,
} :: { [string]: (token: Types.Token) -> Types.Node }

return Handlers
