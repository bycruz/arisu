local Image = require("arisu-image")

local Compute = require("arisu.tools.compute")

local Arisu = require("arisu-app")
local Element = require("arisu-app.ui.element")

-- Builtins
local WindowPlugin = require("arisu-app.plugin.window")
local RenderPlugin = require("arisu-app.plugin.render")
local LayoutPlugin = require("arisu-app.plugin.layout")
local TextPlugin = require("arisu-app.plugin.text")
local UIPlugin = require("arisu-app.plugin.ui")

local OverlayPlugin = require("arisu.plugin.overlay")

---@alias Message
--- | { type: "onWindowCreate", window: winit.Window }
--- | { type: "ToolClicked", tool: App.Tool }
--- | { type: "ClearClicked" }
--- | { type: "SaveClicked" }
--- | { type: "OpenClicked" }
--- | { type: "StartDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "StopDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "Hovered", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "ColorClicked", r: number, g: number, b: number }

---@class App.Resources.Icons
---@field brush Texture
---@field eraser Texture
---@field pencil Texture
---@field bucket Texture
---@field text Texture
---@field palette Texture
---@field select Texture
---@field paste Texture
---@field magnifier Texture
---@field sound Texture
---@field soundMute Texture
---@field vector Texture
---@field copy Texture
---@field cut Texture
---@field crop Texture
---@field resize Texture
---@field rotate Texture
---@field brushes Texture
---@field square Texture
---@field circle Texture
---@field line Texture
---@field curve Texture

---@class App.Resources.Textures
---@field canvas Texture

---@class App.Resources
---@field textures App.Resources.Textures
---@field icons App.Resources.Icons
---@field compute Compute

---@class App.Plugins
---@field window arisu.plugin.Window
---@field render arisu.plugin.Render
---@field text arisu.plugin.Text
---@field ui arisu.plugin.UI
---@field layout arisu.plugin.Layout
---@field overlay plugin.Overlay

---@alias App.Tool "brush" | "eraser" | "fill" | "pencil" | "text" | "select" | "square" | "circle" | "line" | "curve"

---@alias App.Action
--- | { tool: "select", start: { x: number, y: number }?, finish: { x: number, y: number }? }
--- | { tool: "line", start: { x: number, y: number }?, finish: { x: number, y: number }? }
--- | { tool: App.Tool }

---@class App
---@field plugins App.Plugins
---@field resources App.Resources
---@field isDrawing boolean
---@field currentColor { r: number, g: number, b: number, a: number }
---@field currentAction App.Action
---@field startTime number
---@field overlaySelection { start: { x: number, y: number }, finish: { x: number, y: number }? }?
local App = {}
App.__index = App

function App.new()
	local self = setmetatable({ plugins = {} }, App)
	self.plugins.window = WindowPlugin.new({ type = "onWindowCreate" })
	self.plugins.render = RenderPlugin.new(self.plugins.window)
	self.plugins.text = TextPlugin.new(self.plugins.render)
	self.plugins.layout = LayoutPlugin.new(function(w)
		return self:view(w)
	end, self.plugins.text)
	self.plugins.ui = UIPlugin.new(self.plugins.layout, self.plugins.render)
	self.plugins.overlay = OverlayPlugin.new(self.plugins.render)

	self.isDrawing = false
	self.currentColor = { r = 0, g = 0, b = 0, a = 1 }
	self.currentAction = { tool = "brush" }
	self.startTime = os.clock()
	self.overlaySelection = nil
	self.overlayLine = nil
	self.overlayRectangle = nil
	self.overlayCircle = nil

	return self
end

function App:makeResources() ---@return App.Resources
	local textureManager = self.plugins.render.sharedResources.textureManager
	local canvas = textureManager:allocate(800, 600)

	return {
		---@type App.Resources.Icons
		---@format disable-next
		icons = {
			brush = textureManager:upload(assert(Image.fromPath("assets/icons/brush.qoi"), "Brush icon not found")),
			eraser = textureManager:upload(assert(Image.fromPath("assets/icons/david/eraser.qoi"), "Eraser icon not found")),
			pencil = textureManager:upload(assert(Image.fromPath("assets/icons/pencil.qoi"), "Pencil icon not found")),
			bucket = textureManager:upload(assert(Image.fromPath("assets/icons/bucket.qoi"), "Bucket icon not found")),
			text = textureManager:upload(assert(Image.fromPath("assets/icons/text.qoi"), "Text icon not found")),
			palette = textureManager:upload(assert(Image.fromPath("assets/icons/palette.qoi"), "Palette icon not found")),
			select = textureManager:upload(assert(Image.fromPath("assets/icons/select.qoi"), "Select icon not found")),
			paste = textureManager:upload(assert(Image.fromPath("assets/icons/paste.qoi"), "Paste icon not found")),
			magnifier = textureManager:upload(assert(Image.fromPath("assets/icons/magnifier.qoi"), "Magnifier icon not found")),
			sound = textureManager:upload(assert(Image.fromPath("assets/icons/sound.qoi"), "Sound icon not found")),
			soundMute = textureManager:upload(assert(Image.fromPath("assets/icons/sound_mute.qoi"), "Sound mute icon not found")),
			vector = textureManager:upload(assert(Image.fromPath("assets/icons/vector.qoi"), "Vector icon not found")),
			copy = textureManager:upload(assert(Image.fromPath("assets/icons/copy.qoi"), "Copy icon not found")),
			cut = textureManager:upload(assert(Image.fromPath("assets/icons/cut.qoi"), "Cut icon not found")),
			crop = textureManager:upload(assert(Image.fromPath("assets/icons/crop.qoi"), "Crop icon not found")),
			resize = textureManager:upload(assert(Image.fromPath("assets/icons/resize.qoi"), "Resize icon not found")),
			rotate = textureManager:upload(assert(Image.fromPath("assets/icons/rotate.qoi"), "Rotate icon not found")),
			brushes = textureManager:upload(assert(Image.fromPath("assets/icons/brushes.qoi"), "Brushes icon not found")),
			square = textureManager:upload(assert(Image.fromPath("assets/icons/david/square.qoi"), "Square icon not found")),
			circle = textureManager:upload(assert(Image.fromPath("assets/icons/david/circle.qoi"), "Circle icon not found")),
			line = textureManager:upload(assert(Image.fromPath("assets/icons/david/line.qoi"), "Line icon not found")),
			curve = textureManager:upload(assert(Image.fromPath("assets/icons/david/curve.qoi"), "Curve icon not found")),
		},

		---@type App.Resources.Textures
		textures = {
			canvas = canvas,
		},

		compute = Compute.new(textureManager, canvas, self.plugins.render.device),
	}
end

---@generic T, V
---@param list T[]
---@param fn fun(item: T): V
---@return V[]
local function map(list, fn)
	local result = {}
	for i, item in ipairs(list) do
		result[i] = fn(item)
	end
	return result
end

---@param window winit.Window
function App:view(window)
	local disabledColor = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 }
	local selectedColor = { r = 0.7, g = 0.7, b = 1.0, a = 1.0 }
	local borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
	local squareBorder = {
		top = { width = 1, color = borderColor },
		bottom = { width = 1, color = borderColor },
		left = { width = 1, color = borderColor },
		right = { width = 1, color = borderColor },
	}

	local function toolBg(tool)
		if tool == "text" then
			return disabledColor
		end

		if self.currentAction.tool == tool then
			return selectedColor
		else
			return { r = 0.9, g = 0.9, b = 0.9, a = 1.0 }
		end
	end

	local colorPalette1 = {
		{ r = 0.0, g = 0.0, b = 0.0 },
		{ r = 1.0, g = 0.0, b = 0.0 },
		{ r = 0.0, g = 1.0, b = 0.0 },
		{ r = 0.0, g = 0.0, b = 1.0 },
		{ r = 1.0, g = 1.0, b = 0.0 },
		{ r = 1.0, g = 0.0, b = 1.0 },
		{ r = 0.0, g = 1.0, b = 1.0 },
	}

	local colorPalette2 = {
		{ r = 0.5, g = 0.5, b = 0.5 },
		{ r = 0.5, g = 0.0, b = 0.0 },
		{ r = 0.0, g = 0.5, b = 0.0 },
		{ r = 0.0, g = 0.0, b = 0.5 },
		{ r = 0.5, g = 0.5, b = 0.0 },
		{ r = 0.5, g = 0.0, b = 0.5 },
		{ r = 0.0, g = 0.5, b = 0.5 },
	}

	local function makeColorRow(colors)
		return Element.new("div")
			:withStyle({ direction = "row", height = { rel = 0.5 } })
			:withChildren(map(colors, function(color)
				return Element.new("div")
					:withStyle({
						width = { abs = 30 },
						height = { abs = 30 },
						bg = { r = color.r, g = color.g, b = color.b, a = 1.0 },
						border = squareBorder,
						margin = { all = 1 },
					})
					:onClick({ type = "ColorClicked", r = color.r, g = color.g, b = color.b })
			end))
	end

	local function makeIconButton(icon, label)
		return Element.new("div")
			:withStyle({
				direction = "row",
				gap = 5,
				height = { rel = 1 / 3 },
			})
			:withChildren({
				Element.new("div"):withStyle({
					bgImage = icon,
					width = { abs = 15 },
					height = { abs = 15 },
					margin = { right = 2 },
				}),
				Element.from(label):withStyle({ fg = disabledColor, height = { rel = 1.0 } }),
			})
	end

	return Element.new("div")
		:withStyle({
			direction = "column",
			bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
		})
		:withChildren({
			Element.new("div")
				:withStyle({
					height = { abs = 30 },
					direction = "row",
					align = "center",
					gap = 5,
					padding = { left = 5, top = 5 },
					border = { bottom = { width = 1, color = borderColor } },
				})
				:withChildren({
					Element.from("Open"):withStyle({ width = { abs = 50 } }):onClick({ type = "OpenClicked" }),
					Element.from("Save"):withStyle({ width = { abs = 50 } }):onClick({ type = "SaveClicked" }),
					Element.from("Edit"):withStyle({ fg = disabledColor, width = { abs = 50 } }),
					Element.from("View"):withStyle({ fg = disabledColor, width = { abs = 50 } }),
					Element.from("Clear"):withStyle({ width = { abs = 50 } }):onClick({ type = "ClearClicked" }),
				}),

			Element.new("div")
				:withStyle({
					height = { abs = 100 },
					direction = "row",
					align = "center",
					padding = { bottom = 2 },
				})
				:withChildren({
					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 150 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									padding = { top = 6, bottom = 6, left = 6, right = 6 },
									height = { rel = 0.7 },
									gap = 16,
									direction = "row",
								})
								:withChildren({
									Element.new("div")
										:withStyle({
											direction = "column",
											width = { rel = 1 / 3 },
											height = { rel = 1.0 },
											gap = 8,
										})
										:withChildren({
											Element.new("div"):withStyle({
												bgImage = self.resources.icons.paste,
												height = { rel = 2 / 3 },
											}),
											Element.from("Paste"):withStyle({ fg = disabledColor, height = { rel = 1 / 3 } }),
										}),
									Element.new("div")
										:withStyle({
											direction = "column",
											width = { rel = 1 / 2 },
											height = { rel = 1 },
											gap = 2,
										})
										:withChildren({
											makeIconButton(self.resources.icons.cut, "Cut"),
											makeIconButton(self.resources.icons.copy, "Copy"),
										}),
								}),
							Element.from("Clipboard"):withStyle({
								align = "center",
								justify = "center",
								fg = disabledColor,
								height = { rel = 0.3 },
							}),
						}),

					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 180 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									padding = { top = 3, bottom = 3, left = 3, right = 3 },
									height = { rel = 0.7 },
									gap = 16,
									direction = "row",
								})
								:withChildren({
									Element.new("div")
										:withStyle({
											direction = "column",
											width = { rel = 1 / 3 },
											height = { rel = 1.0 },
											gap = 8,
										})
										:withChildren({
											Element.new("div")
												:withStyle({
													border = squareBorder,
													bgImage = self.resources.icons.select,
													height = { rel = 2 / 3 },
												})
												:onClick({ type = "ToolClicked", tool = "select" }),
											Element.from("Select"):withStyle({ height = { rel = 1 / 3 } }),
										}),
									Element.new("div")
										:withStyle({
											direction = "column",
											width = { rel = 1 / 2 },
											height = { rel = 1.0 },
											gap = 2,
										})
										:withChildren({
											makeIconButton(self.resources.icons.crop, "Crop"),
											makeIconButton(self.resources.icons.resize, "Resize"),
											makeIconButton(self.resources.icons.rotate, "Rotate"),
										}),
								}),
							Element.from("Image"):withStyle({
								align = "center",
								justify = "center",
								height = { rel = 0.3 },
							}),
						}),

					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 120 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									padding = { top = 3, bottom = 3, left = 3, right = 3 },
									height = { rel = 0.7 },
									direction = "column",
								})
								:withChildren({
									Element.new("div")
										:withStyle({
											direction = "row",
											height = { rel = 0.5 },
											padding = { bottom = 1 },
										})
										:withChildren({
											Element.new("div")
												:withStyle({
													width = { abs = 35 },
													height = { abs = 35 },
													bg = toolBg("brush"),
													bgImage = self.resources.icons.brush,
													margin = { right = 1 },
												})
												:onClick({ type = "ToolClicked", tool = "brush" }),
											Element.new("div")
												:withStyle({
													width = { abs = 35 },
													height = { abs = 35 },
													bg = toolBg("eraser"),
													bgImage = self.resources.icons.eraser,
													margin = { right = 1 },
												})
												:onClick({ type = "ToolClicked", tool = "eraser" }),
											Element.new("div")
												:withStyle({
													width = { abs = 35 },
													height = { abs = 35 },
													bg = toolBg("fill"),
													bgImage = self.resources.icons.bucket,
												})
												:onClick({ type = "ToolClicked", tool = "fill" }),
										}),
									Element.new("div")
										:withStyle({
											direction = "row",
											height = { rel = 0.5 },
											gap = 3,
										})
										:withChildren({
											Element.new("div")
												:withStyle({
													width = { abs = 35 },
													height = { abs = 35 },
													bg = toolBg("pencil"),
													bgImage = self.resources.icons.pencil,
												})
												:onClick({ type = "ToolClicked", tool = "pencil" }),
											Element.new("div"):withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = toolBg("text"),
												bgImage = self.resources.icons.text,
											}),
											Element.new("div"):withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = disabledColor,
												bgImage = self.resources.icons.magnifier,
											}),
										}),
								}),
							Element.from("Tools"):withStyle({
								align = "center",
								justify = "center",
								height = { rel = 0.3 },
							}),
						}),

					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 100 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									align = "center",
									justify = "center",
									padding = { top = 3, bottom = 3, left = 3, right = 3 },
									height = { rel = 0.7 },
								})
								:withChildren({
									Element.new("div"):withStyle({
										width = { abs = 50 },
										height = { abs = 50 },
										bgImage = self.resources.icons.brushes,
									}),
								}),
							Element.from("Brushes"):withStyle({
								align = "center",
								justify = "center",
								fg = disabledColor,
								height = { rel = 0.3 },
							}),
						}),

					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 230 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									direction = "column",
									margin = { top = 3, bottom = 3, left = 3, right = 3 },
									border = squareBorder,
									height = { rel = 0.7 },
								})
								:withChildren({
									Element.new("div")
										:withStyle({
											direction = "row",
											height = { abs = 28 },
										})
										:withChildren({
											Element.new("div")
												:withStyle({
													width = { abs = 28 },
													height = { abs = 28 },
													bgImage = self.resources.icons.line,
													bg = toolBg("line"),
												})
												:onClick({ type = "ToolClicked", tool = "line" }),
											Element.new("div")
												:withStyle({
													width = { abs = 28 },
													height = { abs = 28 },
													bgImage = self.resources.icons.curve,
													bg = toolBg("curve"),
												})
												:onClick({ type = "ToolClicked", tool = "curve" }),
										}),
									Element.new("div")
										:withStyle({
											direction = "row",
											height = { abs = 28 },
										})
										:withChildren({
											Element.new("div")
												:withStyle({
													width = { abs = 28 },
													height = { abs = 28 },
													bgImage = self.resources.icons.square,
													bg = toolBg("square"),
												})
												:onClick({ type = "ToolClicked", tool = "square" }),
											Element.new("div")
												:withStyle({
													width = { abs = 28 },
													height = { abs = 28 },
													bgImage = self.resources.icons.circle,
													bg = toolBg("circle"),
												})
												:onClick({ type = "ToolClicked", tool = "circle" }),
										}),
								}),
							Element.from("Shapes"):withStyle({
								align = "center",
								justify = "center",
								height = { rel = 0.3 },
							}),
						}),

					Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 300 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } },
						})
						:withChildren({
							Element.new("div")
								:withStyle({
									padding = { top = 3, bottom = 3, left = 3, right = 3 },
									height = { rel = 0.7 },
									direction = "row",
									align = "center",
									gap = 5,
								})
								:withChildren({
									Element.new("div"):withStyle({
										width = { abs = 40 },
										height = { abs = 40 },
										bg = self.currentColor,
										border = squareBorder,
										margin = { right = 5 },
									}),
									Element.new("div")
										:withStyle({
											direction = "column",
											justify = "center",
										})
										:withChildren({
											makeColorRow(colorPalette1),
											makeColorRow(colorPalette2),
										}),
								}),
							Element.from("Colors"):withStyle({
								align = "center",
								justify = "center",
								height = { rel = 0.3 },
							}),
						}),
				}),

			Element.new("div")
				:withStyle({
					height = "auto",
					align = "center",
					justify = "center",
					bg = { r = 0.7, g = 0.7, b = 0.8, a = 1.0 },
				})
				:withChildren({
					-- White background for canvas
					Element.new("div"):withStyle({
						bg = { r = 1, g = 1, b = 1, a = 1 },
						width = { rel = 1 },
						height = { rel = 1 },
						position = "relative",
						margin = { right = 20, left = 20, top = 20, bottom = 20 },
					}),
					Element.new("div")
						:withStyle({
							bgImage = self.resources.textures.canvas,
							width = { rel = 1 },
							height = { rel = 1 },
							margin = { right = 20, left = 20, top = 20, bottom = 20 },
						})
						:onMouseDown(function(x, y, elementWidth, elementHeight)
							return {
								type = "StartDrawing",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight,
							}
						end)
						:onMouseUp(function(x, y, elementWidth, elementHeight)
							return {
								type = "StopDrawing",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight,
							}
						end)
						:onMouseMove(function(x, y, elementWidth, elementHeight)
							return {
								type = "Hovered",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight,
							}
						end),
					Element.new("div"):withStyle({
						bgImage = assert(self.plugins.overlay:getTexture(window), "Overlay texture not found"),
						width = { rel = 1 },
						height = { rel = 1 },
						margin = { right = 20, left = 20, top = 20, bottom = 20 },
						position = "relative",
					}),
				}),

			Element.new("div")
				:withStyle({
					height = { abs = 30 },
					width = "auto",
				})
				:withChildren({
					Element.from("arisu v0.5.0-beta"):withStyle({
						align = "center",
						padding = { left = 10 },
					}),
				}),
		})
end

---@param event winit.Event
---@param handler winit.EventManager
function App:event(event, handler)
	-- handler:setMode("poll")

	-- if event.name == "aboutToWait" then
	-- 	for window in pairs(self.plugins.window.contexts) do
	-- 		handler:requestRedraw(window)
	-- 	end
	-- end

	local windowUpdate = self.plugins.window:event(event, handler)
	if windowUpdate then
		return windowUpdate
	end

	if event.name == "redraw" then
		local ctx = self.plugins.render:getContext(event.window)
		self.plugins.render:draw(ctx)

		self.plugins.overlay:clear(event.window)

		if self.overlaySelection then
			local start = self.overlaySelection.start
			local finish = self.overlaySelection.finish or start

			local x1 = start.x
			local y1 = start.y
			local x2 = finish.x
			local y2 = finish.y

			local boxX = math.min(x1, x2)
			local boxY = math.min(y1, y2)
			local boxW = math.abs(x2 - x1)
			local boxH = math.abs(y2 - y1)

			self.plugins.overlay:addBox(event.window, boxX, boxY, boxW, boxH, { r = 0, g = 0, b = 0, a = 1 }, 2)
		end

		if self.overlayLine then
			local start = self.overlayLine.start
			local finish = self.overlayLine.finish or start

			self.plugins.overlay:addLine(event.window, start.x, start.y, finish.x, finish.y, self.currentColor, 2)
		end

		if self.overlayRectangle then
			local start = self.overlayRectangle.start
			local finish = self.overlayRectangle.finish or start

			local x1 = start.x
			local y1 = start.y
			local x2 = finish.x
			local y2 = finish.y

			local boxX = math.min(x1, x2)
			local boxY = math.min(y1, y2)
			local boxW = math.abs(x2 - x1)
			local boxH = math.abs(y2 - y1)

			self.plugins.overlay:addBox(event.window, boxX, boxY, boxW, boxH, self.currentColor, 2)
		end

		if self.overlayCircle then
			local start = self.overlayCircle.start
			local finish = self.overlayCircle.finish or start

			self.plugins.overlay:addEllipse(event.window, start.x, start.y, finish.x, finish.y, self.currentColor, 2)
		end

		local time = os.clock() - self.startTime
		self.plugins.overlay:draw(event.window, "marching_ants", time)

		self.plugins.render.device.queue:present(ctx.swapchain)

		if self.overlaySelection or self.overlayLine or self.overlayRectangle or self.overlayCircle then
			handler:requestRedraw(event.window)
		end

		return nil
	end

	local renderUpdate = self.plugins.render:event(event, handler)
	if renderUpdate then
		return renderUpdate
	end

	local layoutUpdate = self.plugins.layout:event(event)
	if layoutUpdate then
		return layoutUpdate
	end
end

---@param message Message
---@param window winit.Window
function App:update(message, window)
	if message.type == "onWindowCreate" then
		window:setTitle("Arisu")

		-- Now we can initialize assets for a specific window
		self.plugins.render:register(window)
		self.plugins.overlay:register(window)

		if window == self.plugins.window.mainCtx.window then
			self.resources = self:makeResources()
		end

		self.plugins.layout:register(window)
		self.plugins.ui:refreshView(window)
	elseif message.type == "StartDrawing" then
		if self.currentAction.tool == "fill" then
			self.resources.compute:fill(
				(message.x / message.elementWidth) * 800,
				(message.y / message.elementHeight) * 600,
				self.currentColor
			)
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "brush" then
			self.resources.compute:stamp(
				(message.x / message.elementWidth) * 800,
				(message.y / message.elementHeight) * 600,
				10,
				self.currentColor
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "select" then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600
			self.overlaySelection = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "pencil" then
			self.resources.compute:stamp(
				(message.x / message.elementWidth) * 800,
				(message.y / message.elementHeight) * 600,
				1,
				self.currentColor
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "eraser" then
			self.resources.compute:erase(
				(message.x / message.elementWidth) * 800,
				(message.y / message.elementHeight) * 600,
				10
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "line" then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600
			self.overlayLine = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "square" then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600
			self.overlayRectangle = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "circle" then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600
			self.overlayCircle = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		end
	elseif message.type == "StopDrawing" then
		if self.currentAction.tool == "select" and self.overlaySelection then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600

			local start = self.overlaySelection.start
			if start.x == x and start.y == y then
				self.resources.compute:resetSelection()
				self.overlaySelection = nil
			else
				local startPos = { x = math.min(start.x, x), y = math.min(start.y, y) }
				local finishPos = { x = math.max(start.x, x), y = math.max(start.y, y) }
				self.resources.compute:setSelection(startPos.x, startPos.y, finishPos.x, finishPos.y)
				self.overlaySelection.finish = { x = x, y = y }
			end
		elseif self.currentAction.tool == "line" and self.overlayLine then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600

			local start = self.overlayLine.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawLine(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayLine = nil
		elseif self.currentAction.tool == "square" and self.overlayRectangle then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600

			local start = self.overlayRectangle.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawRectangle(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayRectangle = nil
		elseif self.currentAction.tool == "circle" and self.overlayCircle then
			local x = (message.x / message.elementWidth) * 800
			local y = (message.y / message.elementHeight) * 600

			local start = self.overlayCircle.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawEllipse(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayCircle = nil
		end
		self.isDrawing = false
		window.shouldRedraw = true
	elseif message.type == "Hovered" then
		if self.isDrawing then
			if self.currentAction.tool == "eraser" then
				self.resources.compute:erase(
					(message.x / message.elementWidth) * 800,
					(message.y / message.elementHeight) * 600,
					10
				)
			elseif self.currentAction.tool == "brush" then
				self.resources.compute:stamp(
					(message.x / message.elementWidth) * 800,
					(message.y / message.elementHeight) * 600,
					10,
					self.currentColor
				)
			elseif self.currentAction.tool == "pencil" then
				self.resources.compute:stamp(
					(message.x / message.elementWidth) * 800,
					(message.y / message.elementHeight) * 600,
					1,
					self.currentColor
				)
			elseif self.currentAction.tool == "select" and self.overlaySelection then
				local x = (message.x / message.elementWidth) * 800
				local y = (message.y / message.elementHeight) * 600
				self.overlaySelection.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "line" and self.overlayLine then
				local x = (message.x / message.elementWidth) * 800
				local y = (message.y / message.elementHeight) * 600
				self.overlayLine.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "square" and self.overlayRectangle then
				local x = (message.x / message.elementWidth) * 800
				local y = (message.y / message.elementHeight) * 600
				self.overlayRectangle.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "circle" and self.overlayCircle then
				local x = (message.x / message.elementWidth) * 800
				local y = (message.y / message.elementHeight) * 600
				self.overlayCircle.finish = { x = x, y = y }
				window.shouldRedraw = true
			end
			self.plugins.ui:requestRedraw(window)
		end
	elseif message.type == "ColorClicked" then
		self.currentColor = { r = message.r, g = message.g, b = message.b, a = 1.0 }
		self.plugins.ui:refreshView(window)
	elseif message.type == "ToolClicked" then
		self.currentAction = { tool = message.tool }
		self.plugins.ui:refreshView(window)
	elseif message.type == "ClearClicked" then
		-- TODO: this is awful since we dont free the old resources
		local textureManager = self.plugins.render.sharedResources.textureManager
		local canvas = textureManager:allocate(800, 600)
		self.resources.textures.canvas = canvas
		self.resources.compute = Compute.new(textureManager, canvas, self.plugins.render.device)
		self.plugins.ui:refreshView(window)
	elseif message.type == "OpenClicked" then
		print("Open clicked - not implemented")
	elseif message.type == "SaveClicked" then
		print("Save clicked - not implemented")
	end
end

Arisu.run(App)
