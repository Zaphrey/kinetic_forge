--!strict
--!optimize 2
--!native

local Stack = {} :: StackImpl
Stack.__index = Stack

Stack.__len = function<T>(t: StackData<T>): number
	return #t.array
end

export type StackData<T> = {
	array: { T }
}

export type StackImpl = {
	__index: StackImpl,
	__len: <T>(t: StackData<T>) -> number,
	new: <T>(initial: { T }?) -> Stack<T>,
	push: <T>(self: StackData<T>, item: T) -> (),
	peek: <T>(self: StackData<T>) -> T,
	pop: <T>(self: StackData<T>) -> T,
}

export type Stack<T> = StackData<T> & {
	push: (self: StackData<T>, item: T) -> (),
	peek: (self: StackData<T>) -> T,
	pop: (self: StackData<T>) -> T,
}

function Stack.new<T>(initial: { T }?): Stack<T>
	local self: StackData<T> = {
		array = initial or {} :: { T }
	}
	
	--print(initial)

	return (setmetatable(self, Stack) :: any) :: Stack<T>
end

-- Pushes an item to the top of the stack
function Stack.push<T>(self: StackData<T>, item: T)
	table.insert(self.array, item)
end

function Stack.peek<T>(self: StackData<T>): T
	assert(#self.array > 0, "Stack is empty")
	return self.array[#self.array]
end

function Stack.pop<T>(self: StackData<T>): T
	assert(#self.array > 0, "Stack is empty")
	
	const item = table.remove(self.array)
	
	assert(item ~= nil, "Stack is empty")
	
	return item
end


return Stack