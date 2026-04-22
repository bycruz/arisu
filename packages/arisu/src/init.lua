local ffi = require("ffi")
local Image = require("arisu-image")

local Compute = require("arisu.tools.compute")

local Arisu = require("arisu-app")
local Element = require("arisu-layout.element")

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
--- | { type: "OpenPopupClosed" }
--- | { type: "FilePathChanged", value: string }
--- | { type: "FilePathSubmit", value: string }
--- | { type: "StartDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "StopDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "Hovered", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "ColorClicked", r: number, g: number, b: number }
--- | { type: "CompleteCurve" }
--- | { type: "BrushesToggled" }
--- | { type: "BrushSizeSelected", size: number }

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
---@field canvasWidth number
---@field canvasHeight number

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
---@field brushesOpen boolean
---@field brushSize number
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
	self.overlayCurve = nil
	self.overlayText = nil
	self.filePickerPath = ""
	self.brushesOpen = false
	self.brushSize = 10

	return self
end

function App:makeResources() ---@return App.Resources
	local textureManager = self.plugins.render.sharedResources.textureManager
	local canvas = textureManager:allocate(800, 600)
	local canvasWidth, canvasHeight = textureManager:getSize(canvas)

	return {
		---@type App.Resources.Icons
		---@format disable-next
		icons = {
			brush = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.brush")), "Brush icon not found")),
			eraser = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.david.eraser")), "Eraser icon not found")),
			pencil = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.pencil")), "Pencil icon not found")),
			bucket = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.bucket")), "Bucket icon not found")),
			text = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.text")), "Text icon not found")),
			palette = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.palette")), "Palette icon not found")),
			select = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.select")), "Select icon not found")),
			paste = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.paste")), "Paste icon not found")),
			magnifier = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.magnifier")), "Magnifier icon not found")),
			sound = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.sound")), "Sound icon not found")),
			soundMute = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.sound_mute")), "Sound mute icon not found")),
			vector = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.vector")), "Vector icon not found")),
			copy = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.copy")), "Copy icon not found")),
			cut = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.cut")), "Cut icon not found")),
			crop = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.crop")), "Crop icon not found")),
			resize = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.resize")), "Resize icon not found")),
			rotate = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.rotate")), "Rotate icon not found")),
			brushes = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.brushes")), "Brushes icon not found")),
			square = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.david.square")), "Square icon not found")),
			circle = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.david.circle")), "Circle icon not found")),
			line = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.david.line")), "Line icon not found")),
			curve = textureManager:upload(assert(Image.fromData(require("arisu.assets.icons.david.curve")), "Curve icon not found")),
		},

		---@type App.Resources.Textures
		textures = {
			canvas = canvas
		},

		canvasWidth = canvasWidth,
		canvasHeight = canvasHeight,
		compute = Compute.new(textureManager, canvas, self.plugins.render.device)
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
function App:filePickerView(window)
	local borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
	local focusedId = self.plugins.layout:getFocusedId(window)
	local cursorPos = self.plugins.layout:getCursorPos(window)

	local displayValue = self.filePickerPath
	if focusedId == "filePath" then
		displayValue = displayValue:sub(1, cursorPos) .. "|" .. displayValue:sub(cursorPos + 1)
	else
		displayValue = #displayValue > 0 and displayValue or " "
	end

	local focusBorderColor = { r = 0.3, g = 0.5, b = 1, a = 1 }
	local inputBorder = focusedId == "filePath" and {
		top    = { width = 2, color = focusBorderColor },
		bottom = { width = 2, color = focusBorderColor },
		left   = { width = 2, color = focusBorderColor },
		right  = { width = 2, color = focusBorderColor }
	} or {
		top    = { width = 1, color = borderColor },
		bottom = { width = 1, color = borderColor },
		left   = { width = 1, color = borderColor },
		right  = { width = 1, color = borderColor }
	}

	return Element.new("div")
		:withStyle({ direction = "column", bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 } })
		:withChildren({
			Element.new("div")
				:withStyle({
					height = { abs = 30 },
					direction = "row",
					align = "center",
					padding = { left = 5 },
					border = { bottom = { width = 1, color = borderColor } }
				})
				:withChildren({ Element.from("Open File") }),
			Element.new("div")
				:withStyle({ height = "auto", padding = { all = 10 }, direction = "column", gap = 6 })
				:withChildren({
					Element.from("File path:"):withStyle({ height = { abs = 14 } }),
					Element.new("div")
						:withStyle({
							height = { abs = 26 },
							bg = { r = 1, g = 1, b = 1, a = 1 },
							border = inputBorder,
							padding = { left = 4 },
							align = "center"
						})
						:asTextInput({
							id = "filePath",
							value = self.filePickerPath,
							oninput = function(v) return { type = "FilePathChanged", value = v } end,
							onsubmit = function(v) return { type = "FilePathSubmit", value = v } end
						})
						:withChildren({
							Element.from(displayValue):withStyle({ height = { abs = 14 } })
						})
				}),
			Element.new("div")
				:withStyle({
					height = { abs = 40 },
					direction = "row",
					align = "center",
					justify = "center",
					gap = 10,
					border = { top = { width = 1, color = borderColor } }
				})
				:withChildren({
					Element.from("Cancel")
						:withStyle({ width = { abs = 80 }, align = "center" })
						:onClick({ type = "OpenPopupClosed" }),
					Element.from("Open")
						:withStyle({ width = { abs = 80 }, align = "center" })
						:onClick({ type = "FilePathSubmit", value = self.filePickerPath })
				})
		})
end

---@param window winit.Window
function App:view(window)
	if window.kind then
		return self:filePickerView(window)
	end

	local disabledColor = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 }
	local selectedColor = { r = 0.7, g = 0.7, b = 1.0, a = 1.0 }
	local borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
	local squareBorder = {
		top = { width = 1, color = borderColor },
		bottom = { width = 1, color = borderColor },
		left = { width = 1, color = borderColor },
		right = { width = 1, color = borderColor }
	}

	local function toolBg(tool)
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
		{ r = 0.0, g = 1.0, b = 1.0 }
	}

	local colorPalette2 = {
		{ r = 0.5, g = 0.5, b = 0.5 },
		{ r = 0.5, g = 0.0, b = 0.0 },
		{ r = 0.0, g = 0.5, b = 0.0 },
		{ r = 0.0, g = 0.0, b = 0.5 },
		{ r = 0.5, g = 0.5, b = 0.0 },
		{ r = 0.5, g = 0.0, b = 0.5 },
		{ r = 0.0, g = 0.5, b = 0.5 }
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
						margin = { all = 1 }
					})
					:onClick({ type = "ColorClicked", r = color.r, g = color.g, b = color.b })
			end))
	end

	local function makeIconButton(icon, label)
		return Element.new("div")
			:withStyle({
				direction = "row",
				gap = 5,
				height = { rel = 1 / 3 }
			})
			:withChildren({
				Element.new("div"):withStyle({
					bgImage = icon,
					width = { abs = 15 },
					height = { abs = 15 },
					margin = { right = 2 }
				}),
				Element.from(label):withStyle({ fg = disabledColor, height = { rel = 1.0 } })
			})
	end

	local isPortrait = window.width < 1050 or window.height > window.width

	local menuBar = Element.new("div")
		:withStyle({
			height = { abs = 30 },
			direction = "row",
			align = "center",
			gap = 5,
			padding = { left = 5, top = 5 },
			border = { bottom = { width = 1, color = borderColor } }
		})
		:withChildren({
			Element.from("Open"):withStyle({ width = { abs = 50 } }):onClick({ type = "OpenClicked" }),
			Element.from("Save"):withStyle({ width = { abs = 50 } }):onClick({ type = "SaveClicked" }),
			Element.from("Edit"):withStyle({ fg = disabledColor, width = { abs = 50 } }),
			Element.from("View"):withStyle({ fg = disabledColor, width = { abs = 50 } }),
			Element.from("Clear"):withStyle({ width = { abs = 50 } }):onClick({ type = "ClearClicked" })
		})

	local statusBar = Element.new("div")
		:withStyle({
			height = { abs = 30 },
			width = "auto"
		})
		:withChildren({
			Element.from("arisu v0.5.0"):withStyle({
				align = "center",
				padding = { left = 10 }
			})
		})

	local function makeCanvasArea(heightStyle, widthStyle)
		return Element.new("div")
			:withStyle({
				height = heightStyle,
				width = widthStyle or { rel = 1.0 },
				align = "center",
				justify = "center",
				bg = { r = 0.7, g = 0.7, b = 0.8, a = 1.0 }
			})
			:withChildren({
				-- White background for canvas
				Element.new("div"):withStyle({
					bg = { r = 1, g = 1, b = 1, a = 1 },
					width = { rel = 1 },
					height = { rel = 1 },
					position = "relative",
					margin = { right = 20, left = 20, top = 20, bottom = 20 }
				}),
				(function()
					local canvasEl = Element.new("div")
						:withStyle({
							bgImage = self.resources.textures.canvas,
							width = { rel = 1 },
							height = { rel = 1 },
							margin = { right = 20, left = 20, top = 20, bottom = 20 }
						})
						:onMouseDown(function(x, y, elementWidth, elementHeight)
							return {
								type = "StartDrawing",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight
							}
						end)
						:onMouseUp(function(x, y, elementWidth, elementHeight)
							return {
								type = "StopDrawing",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight
							}
						end)
						:onMouseMove(function(x, y, elementWidth, elementHeight)
							return {
								type = "Hovered",
								x = x,
								y = y,
								elementWidth = elementWidth,
								elementHeight = elementHeight
							}
						end)
					if self.currentAction.tool == "curve" then
						canvasEl:onDoubleClick({ type = "CompleteCurve" })
					end
					return canvasEl
				end)(),
				Element.new("div"):withStyle({
					bgImage = assert(self.plugins.overlay:getTexture(window), "Overlay texture not found"),
					width = { rel = 1 },
					height = { rel = 1 },
					margin = { right = 20, left = 20, top = 20, bottom = 20 },
					position = "relative"
				})
			})
	end

	if isPortrait then
		local iconSize = 32
		local function toolBtn(icon, tool)
			return Element.new("div")
				:withStyle({
					width = { abs = iconSize },
					height = { abs = iconSize },
					bg = toolBg(tool),
					bgImage = icon
				})
				:onClick({ type = "ToolClicked", tool = tool })
		end

		local function disabledToolBtn(icon)
			return Element.new("div")
				:withStyle({
					width = { abs = iconSize },
					height = { abs = iconSize },
					bg = disabledColor,
					bgImage = icon
				})
		end

		local shapeSize = 28
		local function shapeBtn(icon, tool)
			return Element.new("div")
				:withStyle({
					width = { abs = shapeSize },
					height = { abs = shapeSize },
					bgImage = icon,
					bg = toolBg(tool),
					border = squareBorder
				})
				:onClick({ type = "ToolClicked", tool = tool })
		end

		local swatchSize = 14
		-- swatchSize + 2px margin each side = 16px per row height
		local function makeCompactColorRow(colors)
			return Element.new("div")
				:withStyle({ direction = "row", height = { abs = swatchSize + 2 } })
				:withChildren(map(colors, function(color)
					return Element.new("div")
						:withStyle({
							width = { abs = swatchSize },
							height = { abs = swatchSize },
							bg = { r = color.r, g = color.g, b = color.b, a = 1.0 },
							border = squareBorder,
							margin = { all = 1 }
						})
						:onClick({ type = "ColorClicked", r = color.r, g = color.g, b = color.b })
				end))
		end

		-- Heights: tools(86) + gap8 + shapes(83) + gap8 + colors(53) + padding(8) = 246px fixed content
		local labelH = 16
		local sidebar = Element.new("div")
			:withStyle({
				direction = "column",
				width = { abs = 130 },
				height = { rel = 1.0 },
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
				border = { right = { width = 1, color = borderColor } },
				padding = { all = 4 },
				gap = 8
			})
			:withChildren({
				-- Tools: 32 + 3gap + 32 + 3gap + 16 = 86px
				Element.new("div")
					:withStyle({ direction = "column", gap = 3, height = { abs = 86 } })
					:withChildren({
						Element.new("div")
							:withStyle({ direction = "row", gap = 3, height = { abs = iconSize } })
							:withChildren({
								toolBtn(self.resources.icons.brush, "brush"),
								toolBtn(self.resources.icons.eraser, "eraser"),
								toolBtn(self.resources.icons.bucket, "fill")
							}),
						Element.new("div")
							:withStyle({ direction = "row", gap = 3, height = { abs = iconSize } })
							:withChildren({
								toolBtn(self.resources.icons.pencil, "pencil"),
								toolBtn(self.resources.icons.select, "select"),
								toolBtn(self.resources.icons.text, "text")
							}),
						Element.from("Tools"):withStyle({ fg = disabledColor, height = { abs = labelH } })
					}),
				-- Shapes: grid(64) + 3gap + 16 = 83px
				Element.new("div")
					:withStyle({ direction = "column", gap = 3, height = { abs = 83 } })
					:withChildren({
						-- grid: 2px border + 2px padding + 28 + 2gap + 28 + 2px padding + 2px border = 64px
						Element.new("div")
							:withStyle({
								direction = "column",
								border = squareBorder,
								gap = 2,
								padding = { all = 2 },
								height = { abs = 64 }
							})
							:withChildren({
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = shapeSize } })
									:withChildren({
										shapeBtn(self.resources.icons.line, "line"),
										shapeBtn(self.resources.icons.curve, "curve")
									}),
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = shapeSize } })
									:withChildren({
										shapeBtn(self.resources.icons.square, "square"),
										shapeBtn(self.resources.icons.circle, "circle")
									})
							}),
						Element.from("Shapes"):withStyle({ fg = disabledColor, height = { abs = labelH } })
					}),
				-- Colors: row(34) + 3gap + 16 = 53px
				Element.new("div")
					:withStyle({ direction = "column", gap = 3, height = { abs = 53 } })
					:withChildren({
						Element.new("div")
							:withStyle({ direction = "row", gap = 4, align = "center", height = { abs = 34 } })
							:withChildren({
								Element.new("div"):withStyle({
									width = { abs = 28 },
									height = { abs = 28 },
									bg = self.currentColor,
									border = squareBorder
								}),
								Element.new("div")
									:withStyle({ direction = "column", gap = 1 })
									:withChildren({
										makeCompactColorRow(colorPalette1),
										makeCompactColorRow(colorPalette2)
									})
							}),
						Element.from("Colors"):withStyle({ fg = disabledColor, height = { abs = labelH } })
					}),
				-- Brushes: icon(32) + 3gap + 16 = 51px
				(function()
					local function brushSizeCell(size)
						local visualSize = math.max(4, math.min(size, 22))
						local isSelected = self.brushSize == size
						local cellBg = isSelected and { r = 0.75, g = 0.9, b = 1.0, a = 1.0 }
							or { r = 1, g = 1, b = 1, a = 1.0 }
						return Element.new("div")
							:withStyle({
								width = { abs = 36 },
								height = { abs = 36 },
								bg = cellBg,
								border = squareBorder,
								align = "center",
								justify = "center"
							})
							:withChildren({
								Element.new("div"):withStyle({
									width = { abs = visualSize },
									height = { abs = visualSize },
									bg = { r = 0, g = 0, b = 0, a = 1 }
								})
							})
							:onClick({ type = "BrushSizeSelected", size = size })
					end

					local sectionChildren = {
						Element.new("div"):withStyle({
							width = { abs = iconSize },
							height = { abs = iconSize },
							bgImage = self.resources.icons.brushes
						})
					}

					if self.brushesOpen then
						sectionChildren[#sectionChildren + 1] = Element.new("div")
							:withStyle({
								position = "relative",
								left = 126,
								top = 0,
								zIndex = 100,
								width = { abs = 124 },
								height = { abs = 88 },
								bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
								border = squareBorder,
								direction = "column",
								padding = { top = 6, bottom = 6, left = 6, right = 6 },
								gap = 4
							})
							:withChildren({
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = 36 } })
									:withChildren({
										brushSizeCell(1),
										brushSizeCell(3),
										brushSizeCell(5)
									}),
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = 36 } })
									:withChildren({
										brushSizeCell(10),
										brushSizeCell(20),
										brushSizeCell(30)
									})
							})
					end

					return Element.new("div")
						:withStyle({ direction = "column", gap = 3, height = { abs = 51 } })
						:withChildren({
							Element.new("div")
								:withStyle({ direction = "row", gap = 3, height = { abs = iconSize } })
								:withChildren(sectionChildren)
								:onClick({ type = "BrushesToggled" }),
							Element.from("Brushes"):withStyle({ fg = disabledColor, height = { abs = labelH } })
						})
				end)()
			})

		return Element.new("div")
			:withStyle({
				direction = "column",
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 }
			})
			:withChildren({
				menuBar,
				Element.new("div")
					:withStyle({ direction = "row", height = "auto" })
					:withChildren({ sidebar, makeCanvasArea({ rel = 1.0 }, "auto") }),
				statusBar
			})
	else
		local toolbar = Element.new("div")
			:withStyle({
				height = { abs = 100 },
				direction = "row",
				align = "center",
				padding = { bottom = 2 }
			})
			:withChildren({
				Element.new("div")
					:withStyle({
						direction = "column",
						width = { abs = 150 },
						height = { rel = 1.0 },
						border = { right = { width = 1, color = borderColor } }
					})
					:withChildren({
						Element.new("div")
							:withStyle({
								padding = { top = 6, bottom = 6, left = 6, right = 6 },
								height = { rel = 0.7 },
								gap = 16,
								direction = "row"
							})
							:withChildren({
								Element.new("div")
									:withStyle({
										direction = "column",
										width = { rel = 1 / 3 },
										height = { rel = 1.0 },
										gap = 8
									})
									:withChildren({
										Element.new("div"):withStyle({
											bgImage = self.resources.icons.paste,
											height = { rel = 2 / 3 }
										}),
										Element.from("Paste"):withStyle({ fg = disabledColor, height = { rel = 1 / 3 } })
									}),
								Element.new("div")
									:withStyle({
										direction = "column",
										width = { rel = 1 / 2 },
										height = { rel = 1 },
										gap = 2
									})
									:withChildren({
										makeIconButton(self.resources.icons.cut, "Cut"),
										makeIconButton(self.resources.icons.copy, "Copy")
									})
							}),
						Element.from("Clipboard"):withStyle({
							align = "center",
							justify = "center",
							fg = disabledColor,
							height = { rel = 0.3 }
						})
					}),

				Element.new("div")
					:withStyle({
						direction = "column",
						width = { abs = 180 },
						height = { rel = 1.0 },
						border = { right = { width = 1, color = borderColor } }
					})
					:withChildren({
						Element.new("div")
							:withStyle({
								padding = { top = 3, bottom = 3, left = 3, right = 3 },
								height = { rel = 0.7 },
								gap = 16,
								direction = "row"
							})
							:withChildren({
								Element.new("div")
									:withStyle({
										direction = "column",
										width = { rel = 1 / 3 },
										height = { rel = 1.0 },
										gap = 8
									})
									:withChildren({
										Element.new("div")
											:withStyle({
												border = squareBorder,
												bgImage = self.resources.icons.select,
												height = { rel = 2 / 3 }
											})
											:onClick({ type = "ToolClicked", tool = "select" }),
										Element.from("Select"):withStyle({ height = { rel = 1 / 3 } })
									}),
								Element.new("div")
									:withStyle({
										direction = "column",
										width = { rel = 1 / 2 },
										height = { rel = 1.0 },
										gap = 2
									})
									:withChildren({
										makeIconButton(self.resources.icons.crop, "Crop"),
										makeIconButton(self.resources.icons.resize, "Resize"),
										makeIconButton(self.resources.icons.rotate, "Rotate")
									})
							}),
						Element.from("Image"):withStyle({
							align = "center",
							justify = "center",
							height = { rel = 0.3 }
						})
					}),

				Element.new("div")
					:withStyle({
						direction = "column",
						width = { abs = 120 },
						height = { rel = 1.0 },
						border = { right = { width = 1, color = borderColor } }
					})
					:withChildren({
						Element.new("div")
							:withStyle({
								padding = { top = 3, bottom = 3, left = 3, right = 3 },
								height = { rel = 0.7 },
								direction = "column"
							})
							:withChildren({
								Element.new("div")
									:withStyle({
										direction = "row",
										height = { rel = 0.5 },
										padding = { bottom = 1 }
									})
									:withChildren({
										Element.new("div")
											:withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = toolBg("brush"),
												bgImage = self.resources.icons.brush,
												margin = { right = 1 }
											})
											:onClick({ type = "ToolClicked", tool = "brush" }),
										Element.new("div")
											:withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = toolBg("eraser"),
												bgImage = self.resources.icons.eraser,
												margin = { right = 1 }
											})
											:onClick({ type = "ToolClicked", tool = "eraser" }),
										Element.new("div")
											:withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = toolBg("fill"),
												bgImage = self.resources.icons.bucket
											})
											:onClick({ type = "ToolClicked", tool = "fill" })
									}),
								Element.new("div")
									:withStyle({
										direction = "row",
										height = { rel = 0.5 },
										gap = 3
									})
									:withChildren({
										Element.new("div")
											:withStyle({
												width = { abs = 35 },
												height = { abs = 35 },
												bg = toolBg("pencil"),
												bgImage = self.resources.icons.pencil
											})
											:onClick({ type = "ToolClicked", tool = "pencil" }),
										Element.new("div"):withStyle({
											width = { abs = 35 },
											height = { abs = 35 },
											bg = toolBg("text"),
											bgImage = self.resources.icons.text
										}):onClick({ type = "ToolClicked", tool = "text" }),
										Element.new("div"):withStyle({
											width = { abs = 35 },
											height = { abs = 35 },
											bg = disabledColor,
											bgImage = self.resources.icons.magnifier
										})
									})
							}),
						Element.from("Tools"):withStyle({
							align = "center",
							justify = "center",
							height = { rel = 0.3 }
						})
					}),

				(function()
					local function brushSizeCell(size)
						local visualSize = math.max(4, math.min(size, 22))
						local isSelected = self.brushSize == size
						local cellBg = isSelected and { r = 0.75, g = 0.9, b = 1.0, a = 1.0 }
							or { r = 1, g = 1, b = 1, a = 1.0 }
						return Element.new("div")
							:withStyle({
								width = { abs = 36 },
								height = { abs = 36 },
								bg = cellBg,
								border = squareBorder,
								align = "center",
								justify = "center"
							})
							:withChildren({
								Element.new("div"):withStyle({
									width = { abs = visualSize },
									height = { abs = visualSize },
									bg = { r = 0, g = 0, b = 0, a = 1 }
								})
							})
							:onClick({ type = "BrushSizeSelected", size = size })
					end

					local sectionChildren = {
						Element.new("div")
							:withStyle({
								align = "center",
								justify = "center",
								padding = { top = 3, bottom = 3, left = 3, right = 3 },
								height = { rel = 0.7 }
							})
							:withChildren({
								Element.new("div"):withStyle({
									width = { abs = 50 },
									height = { abs = 50 },
									bgImage = self.resources.icons.brushes
								})
							}),
						Element.from("Brushes"):withStyle({
							align = "center",
							justify = "center",
							fg = disabledColor,
							height = { rel = 0.3 }
						})
					}

					if self.brushesOpen then
						sectionChildren[#sectionChildren + 1] = Element.new("div")
							:withStyle({
								position = "relative",
								top = 100,
								zIndex = 100,
								width = { abs = 124 },
								height = { abs = 88 },
								bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
								border = squareBorder,
								direction = "column",
								padding = { top = 6, bottom = 6, left = 6, right = 6 },
								gap = 4
							})
							:withChildren({
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = 36 } })
									:withChildren({
										brushSizeCell(1),
										brushSizeCell(3),
										brushSizeCell(5)
									}),
								Element.new("div")
									:withStyle({ direction = "row", gap = 2, height = { abs = 36 } })
									:withChildren({
										brushSizeCell(10),
										brushSizeCell(20),
										brushSizeCell(30)
									})
							})
					end

					return Element.new("div")
						:withStyle({
							direction = "column",
							width = { abs = 100 },
							height = { rel = 1.0 },
							border = { right = { width = 1, color = borderColor } }
						})
						:withChildren(sectionChildren)
						:onClick({ type = "BrushesToggled" })
				end)(),

				Element.new("div")
					:withStyle({
						direction = "column",
						width = { abs = 230 },
						height = { rel = 1.0 },
						border = { right = { width = 1, color = borderColor } }
					})
					:withChildren({
						Element.new("div")
							:withStyle({
								direction = "column",
								margin = { top = 3, bottom = 3, left = 3, right = 3 },
								border = squareBorder,
								height = { rel = 0.7 }
							})
							:withChildren({
								Element.new("div")
									:withStyle({
										direction = "row",
										height = { abs = 28 }
									})
									:withChildren({
										Element.new("div")
											:withStyle({
												width = { abs = 28 },
												height = { abs = 28 },
												bgImage = self.resources.icons.line,
												bg = toolBg("line")
											})
											:onClick({ type = "ToolClicked", tool = "line" }),
										Element.new("div")
											:withStyle({
												width = { abs = 28 },
												height = { abs = 28 },
												bgImage = self.resources.icons.curve,
												bg = toolBg("curve")
											})
											:onClick({ type = "ToolClicked", tool = "curve" })
									}),
								Element.new("div")
									:withStyle({
										direction = "row",
										height = { abs = 28 }
									})
									:withChildren({
										Element.new("div")
											:withStyle({
												width = { abs = 28 },
												height = { abs = 28 },
												bgImage = self.resources.icons.square,
												bg = toolBg("square")
											})
											:onClick({ type = "ToolClicked", tool = "square" }),
										Element.new("div")
											:withStyle({
												width = { abs = 28 },
												height = { abs = 28 },
												bgImage = self.resources.icons.circle,
												bg = toolBg("circle")
											})
											:onClick({ type = "ToolClicked", tool = "circle" })
									})
							}),
						Element.from("Shapes"):withStyle({
							align = "center",
							justify = "center",
							height = { rel = 0.3 }
						})
					}),

				Element.new("div")
					:withStyle({
						direction = "column",
						width = { abs = 300 },
						height = { rel = 1.0 },
						border = { right = { width = 1, color = borderColor } }
					})
					:withChildren({
						Element.new("div")
							:withStyle({
								padding = { top = 3, bottom = 3, left = 3, right = 3 },
								height = { rel = 0.7 },
								direction = "row",
								align = "center",
								gap = 5
							})
							:withChildren({
								Element.new("div"):withStyle({
									width = { abs = 40 },
									height = { abs = 40 },
									bg = self.currentColor,
									border = squareBorder,
									margin = { right = 5 }
								}),
								Element.new("div")
									:withStyle({
										direction = "column",
										justify = "center"
									})
									:withChildren({
										makeColorRow(colorPalette1),
										makeColorRow(colorPalette2)
									})
							}),
						Element.from("Colors"):withStyle({
							align = "center",
							justify = "center",
							height = { rel = 0.3 }
						})
					})
			})

		return Element.new("div")
			:withStyle({
				direction = "column",
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 }
			})
			:withChildren({ menuBar, toolbar, makeCanvasArea("auto"), statusBar })
	end
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

	if event.name == "resize" then
		if self.resources then
			self.plugins.ui:refreshView(event.window)
		end
		return nil
	end

	if event.name == "redraw" then
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

		if self.overlayCurve then
			local pts = {}
			for _, p in ipairs(self.overlayCurve.points) do
				pts[#pts + 1] = p
			end
			if self.overlayCurve.mouse then
				pts[#pts + 1] = self.overlayCurve.mouse
			end
			if #pts >= 2 then
				self.plugins.overlay:addCatmullRom(event.window, pts, self.currentColor, 2)
			end
			for _, p in ipairs(self.overlayCurve.points) do
				self.plugins.overlay:addEllipse(event.window, p.x - 3, p.y - 3, p.x + 3, p.y + 3, self.currentColor, 1)
			end
		end

		local time = os.clock() - self.startTime
		self.plugins.overlay:draw(event.window, "marching_ants", time)

		if self.overlayText then
			local device = self.plugins.render.device
			local textureManager = self.plugins.render.sharedResources.textureManager
			local fontManager = self.plugins.render.sharedResources.fontManager
			local overlayCtx = self.plugins.overlay:getContext(event.window)

			local W, H = 800, 600
			local buf = ffi.new("uint8_t[?]", W * H * 4, 0)

			local color = self.currentColor
			local cr = math.floor(color.r * 255 + 0.5)
			local cg = math.floor(color.g * 255 + 0.5)
			local cb = math.floor(color.b * 255 + 0.5)
			local ca = math.floor(color.a * 255 + 0.5)

			local tx = math.floor(self.overlayText.x)
			local ty = math.floor(self.overlayText.y)
			local penX = tx

			if #self.overlayText.value > 0 then
				local fontBitmap = fontManager:getBitmap(fontManager:getDefault())
				local img = fontBitmap.image
				local imgW, imgH, imgC = img.width, img.height, img.channels
				local imgPixels = img.pixels

				for i = 1, #self.overlayText.value do
					local char = self.overlayText.value:sub(i, i)
					if not fontBitmap.config.characters:find(char, 1, true) then
						penX = penX + fontBitmap.config.gridWidth - (fontBitmap.config.xmargin or 0) * 2
					else
						local quad = fontBitmap:getCharUVs(char)
						local px0 = math.floor(quad.u0 * imgW + 0.5)
						local py0 = math.floor(quad.v0 * imgH + 0.5)
						local pw = quad.width
						local ph = quad.height

						for dy = 0, ph - 1 do
							for dx = 0, pw - 1 do
								local fx = px0 + dx
								local fy = py0 + dy
								if fx >= 0 and fx < imgW and fy >= 0 and fy < imgH then
									local fontIdx = (fy * imgW + fx) * imgC
									local mask = imgPixels[fontIdx]
									if imgC >= 4 then mask = imgPixels[fontIdx + 3] end
									if mask > 127 then
										local cx2 = penX + dx
										local cy2 = ty + dy
										if cx2 >= 0 and cx2 < W and cy2 >= 0 and cy2 < H then
											local idx = (cy2 * W + cx2) * 4
											buf[idx] = cr
											buf[idx + 1] = cg
											buf[idx + 2] = cb
											buf[idx + 3] = ca
										end
									end
								end
							end
						end
						penX = penX + pw
					end
				end
			end

			for y = ty, math.min(ty + 13, H - 1) do
				if penX >= 0 and penX < W and y >= 0 then
					local idx = (y * W + penX) * 4
					buf[idx] = cr
					buf[idx + 1] = cg
					buf[idx + 2] = cb
					buf[idx + 3] = ca
				end
			end

			device.queue:writeTexture(
				textureManager.texture,
				{ layer = overlayCtx.overlayTexture, width = W, height = H },
				buf
			)
		end

		local ctx = self.plugins.render:getContext(event.window)
		self.plugins.render:draw(ctx)

		if self.overlaySelection or self.overlayLine or self.overlayRectangle or self.overlayCircle or self.overlayCurve then
			handler:requestRedraw(event.window)
		end

		return nil
	end

	local renderUpdate = self.plugins.render:event(event, handler)
	if renderUpdate then
		return renderUpdate
	end

	if event.name == "keyPress" then
		if self.overlayText then
			local key = event.key
			if key == "return" then
				if #self.overlayText.value > 0 then
					local fontManager = self.plugins.render.sharedResources.fontManager
					local fontBitmap = fontManager:getBitmap(fontManager:getDefault())
					self.resources.compute:drawText(
						self.overlayText.x,
						self.overlayText.y,
						self.overlayText.value,
						fontBitmap,
						self.currentColor
					)
					self.plugins.ui:refreshView(event.window)
				end
				self.overlayText = nil
				event.window.shouldRedraw = true
			elseif key == "escape" then
				self.overlayText = nil
				event.window.shouldRedraw = true
			elseif key == "backspace" then
				self.overlayText.value = self.overlayText.value:sub(1, -2)
				event.window.shouldRedraw = true
			elseif #key == 1 and key:byte(1) >= 32 then
				self.overlayText.value = self.overlayText.value .. key
				event.window.shouldRedraw = true
			end
			return nil
		elseif event.key == "return" and self.overlayCurve then
			return { type = "CompleteCurve" }
		end
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
		local isMain = window == self.plugins.window.mainCtx.window

		if isMain then
			window:setTitle("Arisu")
			self.plugins.render:register(window)
			self.plugins.overlay:register(window)
			self.resources = self:makeResources()
		else
			window:setTitle(window.kind or "Arisu")
			self.plugins.render:register(window)
		end

		self.plugins.layout:register(window)
		self.plugins.ui:refreshView(window)
	elseif message.type == "StartDrawing" then
		local cw, ch = self.resources.canvasWidth, self.resources.canvasHeight
		if self.currentAction.tool == "fill" then
			self.resources.compute:fill(
				(message.x / message.elementWidth) * cw,
				(message.y / message.elementHeight) * ch,
				self.currentColor
			)
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "brush" then
			self.resources.compute:stamp(
				(message.x / message.elementWidth) * cw,
				(message.y / message.elementHeight) * ch,
				self.brushSize,
				self.currentColor
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "select" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlaySelection = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "pencil" then
			self.resources.compute:stamp(
				(message.x / message.elementWidth) * cw,
				(message.y / message.elementHeight) * ch,
				1,
				self.currentColor
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "eraser" then
			self.resources.compute:erase(
				(message.x / message.elementWidth) * cw,
				(message.y / message.elementHeight) * ch,
				10
			)
			self.isDrawing = true
			self.plugins.ui:refreshView(window)
		elseif self.currentAction.tool == "line" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlayLine = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "square" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlayRectangle = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "circle" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlayCircle = { start = { x = x, y = y }, finish = nil }
			self.isDrawing = true
		elseif self.currentAction.tool == "curve" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			if not self.overlayCurve then
				self.overlayCurve = { points = {}, mouse = nil }
			end
			self.overlayCurve.points[#self.overlayCurve.points + 1] = { x = x, y = y }
			window.shouldRedraw = true
		elseif self.currentAction.tool == "text" then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlayText = { x = x, y = y, value = "" }
			window.shouldRedraw = true
		end
	elseif message.type == "StopDrawing" then
		local cw, ch = self.resources.canvasWidth, self.resources.canvasHeight
		if self.currentAction.tool == "select" and self.overlaySelection then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch

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
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch

			local start = self.overlayLine.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawLine(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayLine = nil
		elseif self.currentAction.tool == "square" and self.overlayRectangle then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch

			local start = self.overlayRectangle.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawRectangle(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayRectangle = nil
		elseif self.currentAction.tool == "circle" and self.overlayCircle then
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch

			local start = self.overlayCircle.start
			if start.x ~= x or start.y ~= y then
				self.resources.compute:drawEllipse(start.x, start.y, x, y, 2, self.currentColor)
				self.plugins.ui:refreshView(window)
			end
			self.overlayCircle = nil
		elseif self.currentAction.tool == "curve" then
			-- curve is completed by double-click or Enter, not mouse release
		end
		if self.currentAction.tool ~= "curve" then
			self.isDrawing = false
		end
		window.shouldRedraw = true
	elseif message.type == "Hovered" then
		if self.overlayCurve then
			local cw, ch = self.resources.canvasWidth, self.resources.canvasHeight
			local x = (message.x / message.elementWidth) * cw
			local y = (message.y / message.elementHeight) * ch
			self.overlayCurve.mouse = { x = x, y = y }
			window.shouldRedraw = true
			self.plugins.ui:requestRedraw(window)
		elseif self.isDrawing then
			local cw, ch = self.resources.canvasWidth, self.resources.canvasHeight
			if self.currentAction.tool == "eraser" then
				self.resources.compute:erase(
					(message.x / message.elementWidth) * cw,
					(message.y / message.elementHeight) * ch,
					10
				)
			elseif self.currentAction.tool == "brush" then
				self.resources.compute:stamp(
					(message.x / message.elementWidth) * cw,
					(message.y / message.elementHeight) * ch,
					self.brushSize,
					self.currentColor
				)
			elseif self.currentAction.tool == "pencil" then
				self.resources.compute:stamp(
					(message.x / message.elementWidth) * cw,
					(message.y / message.elementHeight) * ch,
					1,
					self.currentColor
				)
			elseif self.currentAction.tool == "select" and self.overlaySelection then
				local x = (message.x / message.elementWidth) * cw
				local y = (message.y / message.elementHeight) * ch
				self.overlaySelection.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "line" and self.overlayLine then
				local x = (message.x / message.elementWidth) * cw
				local y = (message.y / message.elementHeight) * ch
				self.overlayLine.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "square" and self.overlayRectangle then
				local x = (message.x / message.elementWidth) * cw
				local y = (message.y / message.elementHeight) * ch
				self.overlayRectangle.finish = { x = x, y = y }
				window.shouldRedraw = true
			elseif self.currentAction.tool == "circle" and self.overlayCircle then
				local x = (message.x / message.elementWidth) * cw
				local y = (message.y / message.elementHeight) * ch
				self.overlayCircle.finish = { x = x, y = y }
				window.shouldRedraw = true
			end
			self.plugins.ui:requestRedraw(window)
		end
	elseif message.type == "CompleteCurve" then
		if self.overlayCurve and #self.overlayCurve.points >= 2 then
			self.resources.compute:drawCatmullRom(self.overlayCurve.points, 2, self.currentColor)
			self.plugins.ui:refreshView(window)
		end
		self.overlayCurve = nil
		self.isDrawing = false
		window.shouldRedraw = true
	elseif message.type == "ColorClicked" then
		self.currentColor = { r = message.r, g = message.g, b = message.b, a = 1.0 }
		self.plugins.ui:refreshView(window)
	elseif message.type == "ToolClicked" then
		if self.overlayCurve then
			self.overlayCurve = nil
			self.isDrawing = false
		end
		if self.overlayText then
			self.overlayText = nil
		end
		self.currentAction = { tool = message.tool }
		self.plugins.ui:refreshView(window)
	elseif message.type == "ClearClicked" then
		-- TODO: this is awful since we dont free the old resources
		local textureManager = self.plugins.render.sharedResources.textureManager
		local canvas = textureManager:allocate(self.resources.canvasWidth, self.resources.canvasHeight)
		self.resources.textures.canvas = canvas
		self.resources.compute = Compute.new(textureManager, canvas, self.plugins.render.device)
		self.plugins.ui:refreshView(window)
	elseif message.type == "OpenClicked" then
		return { type = "createWindow", width = 500, height = 350, kind = "Open File" }
	elseif message.type == "OpenPopupClosed" then
		self.filePickerPath = ""
		return { type = "closeWindow" }
	elseif message.type == "FilePathChanged" then
		self.filePickerPath = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "FilePathSubmit" then
		print("Open file: " .. message.value)
		self.filePickerPath = ""
		return { type = "closeWindow" }
	elseif message.type == "SaveClicked" then
		print("Save clicked - not implemented")
	elseif message.type == "BrushesToggled" then
		self.brushesOpen = not self.brushesOpen
		self.plugins.ui:refreshView(window)
	elseif message.type == "BrushSizeSelected" then
		self.brushSize = message.size
		self.brushesOpen = false
		self.plugins.ui:refreshView(window)
	end
end

Arisu.run(App)
