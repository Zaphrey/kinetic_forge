export type Node = {
	uniqueId: string,
	classname: string,
	tag: string,
	attributes: { [string]: any },
	eventHandlers: { [string]: string },
	childIds: { string },
	innerText: string,
	textBlob: { string },
	parentId: string?,
	element: GuiObject?,
	order: number?,
	level: number?,
	connections: { [string]: RBXScriptConnection }
}

export type TokenType = "TagOpen" | "TagClose" | "TagSelfClose" | "Text" | "Comment" | "EOF"

export type Token = {
	type: TokenType,
	tag: string?,
	value: string?,
	attributes: string?,
	position: number
}

export type Pointers = {
	Class: { [string]: { string } },
	Id: { [string]: string },
}

export type Document = {
	Destroying: BindableEvent,
	Nodes: { [string]: Node },
	Pointers: Pointers,
	NodeCount: number,
	Functions: { 
		[string]: (...any) -> ...any	
	}
}

export type NodeData = {
	tag: string, 
	childIds: { string }?, 
	attributes: { [string]: any }?, 
	eventHandlers: { [string]: InjectableFunction }?,
	innerText: string? 
}

export type DocumentSource = {
	markup: string,
	functions: {
		[string]: InjectableFunction
	},
	styles: StyleSheet?
}

export type InjectableFunction = (object: Node, document: Document?, ...any?) -> ()

return nil