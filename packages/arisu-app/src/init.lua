local window = require("winit")

--[[
	The Arisu app architecture is simple.

	// This is the base type. You decide what it is.
	// Depending on how simple your usecases are, it could just be a string or number.
	type Message<T> = T
	type App<Message> = ...

	An event loop is created which triggers the lowest level "App:event"

	`function App:event(event: Event, handler: EventHandler) -> Message?`
		- If returns, triggers `App:update`
		- Triggered by `Events` which are low level X11/Win32 windowing events.
		- Usually a `Plugin` will register this and you can just worry about defining App:update and App:view

	`function App:update(message: Message) -> Task?`
		- Triggered by `App:event`
		- A task can be returned which will do internal work like creating windows asynchronously

	`function App:view() -> Element`
		- This is used by the base `QuadPlugin` (bad temp name for now)
		- You provide `Message` values as "callbacks" for element click/hover/whatever events.
		- Basically it doesn't really mean anything
		  beyond providing data to the App:event so it can decide things like
		  when to fire an update if your mouse clicked at a certain position.
]]
local Arisu = {}

---@alias arisu.New<T> fun(): arisu.App<T>
---@alias arisu.Update<T> fun(self: arisu.App<T>, message: T, window: winit.Window): arisu.Task?
---@alias arisu.View<T> fun(self: arisu.App<T>, window: winit.Window): arisu.Element
---@alias arisu.Event<T> fun(self: arisu.App<T>, event: winit.Event, handler: winit.EventManager): any

---@class arisu.App<T>: { new: arisu.New<T>, update: arisu.Update<T>, view: arisu.View<T>, event: arisu.Event<T> }

---@alias arisu.Task
--- | { type: "createWindow", width: number?, height: number?, kind: string? }
--- | { type: "closeWindow" }

---@generic Message
---@param appStatic arisu.App<Message>
function Arisu.run(appStatic)
	local app = appStatic.new()

	local eventLoop = window.EventLoop.new()
	window.Window.fromEventLoop(eventLoop)

	eventLoop:run(function(event, handler)
		handler:setMode("poll")

		local message = app:event(event, handler)
		if message then
			local task = app:update(message, event.window)
			if task then
				if task.type == "createWindow" then
					local w = window.Window.new(eventLoop, task.width or 800, task.height or 600)
					if task.kind then w.kind = task.kind end
					eventLoop:register(w)
				elseif task.type == "closeWindow" and event.window then
					handler:close(event.window)
				end
			end
		end
	end)
end

return Arisu
