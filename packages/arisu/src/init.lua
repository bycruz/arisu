local ffi = require("ffi")
local Image = require("arisu-image")
local QOI = require("arisu-image.formats.qoi")

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

local fs = require("fs")
local path = require("path")

local VISIBLE_ENTRIES = 6

---@alias Message
--- | { type: "onWindowCreate", window: winit.Window }
--- | { type: "ToolClicked", tool: App.Tool }
--- | { type: "ClearClicked" }
--- | { type: "SaveClicked" }
--- | { type: "OpenClicked" }
--- | { type: "OpenPopupClosed" }
--- | { type: "FilePathChanged", value: string }
--- | { type: "FilePathSubmit", value: string }
--- | { type: "SavePopupClosed" }
--- | { type: "SaveFilePathChanged", value: string }
--- | { type: "FilePickerNavigate", value: string }
--- | { type: "SavePickerNavigate", value: string }
--- | { type: "FileEntryClicked", value: string }
--- | { type: "SaveEntryClicked", value: string }
--- | { type: "FilePickerDirSubmit", value: string }
--- | { type: "SavePickerDirSubmit", value: string }
--- | { type: "FilePickerScrollUp" }
--- | { type: "FilePickerScrollDown" }
--- | { type: "SavePickerScrollUp" }
--- | { type: "SavePickerScrollDown" }
--- | { type: "StartDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "StopDrawing", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "Hovered", x: number, y: number, elementWidth: number, elementHeight: number }
--- | { type: "ColorClicked", r: number, g: number, b: number }
--- | { type: "CompleteCurve" }
--- | { type: "BrushesToggled" }
--- | { type: "BrushSizeSelected", size: number }
--- | { type: "CanvasSizeClicked" }
--- | { type: "CanvasSizePopupClosed" }
--- | { type: "CanvasWidthChanged", value: string }
--- | { type: "CanvasHeightChanged", value: string }
--- | { type: "CanvasSizeSubmit" }

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
---@field canvasWidthInput string
---@field canvasHeightInput string
---@field filePickerPath string
---@field saveFilePath string
---@field filePickerDir string
---@field filePickerEntries { name: string, type: string }[]
---@field filePickerScroll number
---@field savePickerDir string
---@field savePickerEntries { name: string, type: string }[]
---@field savePickerScroll number
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
	self.saveFilePath = ""
	self.filePickerDir = "."
	self.filePickerEntries = {}
	self.filePickerScroll = 0
	self.savePickerDir = "."
	self.savePickerEntries = {}
	self.savePickerScroll = 0
	self.brushesOpen = false
	self.ribbonOpen = true
	self.brushSize = 10
	self.canvasWidthInput = ""
	self.canvasHeightInput = ""

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

---@param dir string
---@return { name: string, type: string }[]
function App:listDir(dir)
	local entries = {}
	local iter = fs.readdir(dir)
	if not iter then return entries end

	for entry in iter do
		entries[#entries + 1] = { name = entry.name, type = entry.type }
	end

	-- Sort: directories first, then files, alphabetically
	table.sort(entries, function(a, b)
		local aDir = a.type == "dir"
		local bDir = b.type == "dir"
		if aDir ~= bDir then return aDir end
		return a.name:lower() < b.name:lower()
	end)

	return entries
end

---@param p string
---@return string
local function expandHome(p)
	if p:sub(1, 1) == "~" then
		local home = os.getenv("HOME") or "/"
		if p == "~" then
			return home
		else
			return home .. p:sub(2)
		end
	end
	return p
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
---@param mode "open" | "save"
function App:filePickerView(window, mode)
	local borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
	local focusedId = self.plugins.layout:getFocusedId(window)
	local cursorPos = self.plugins.layout:getCursorPos(window)

	local isOpen = mode == "open"
	local pathKey = isOpen and "filePickerPath" or "saveFilePath"
	local dirKey = isOpen and "filePickerDir" or "savePickerDir"
	local entriesKey = isOpen and "filePickerEntries" or "savePickerEntries"
	local inputId = isOpen and "filePath" or "saveFilePath"
	local changeMsg = isOpen and "FilePathChanged" or "SaveFilePathChanged"
	local submitMsg = "FilePathSubmit"
	local closeMsg = isOpen and "OpenPopupClosed" or "SavePopupClosed"
	local navMsg = isOpen and "FilePickerNavigate" or "SavePickerNavigate"
	local fileClickMsg = isOpen and "FileEntryClicked" or "SaveEntryClicked"
	local dirInputId = isOpen and "openDirPath" or "saveDirPath"
	local dirSubmitMsg = isOpen and "FilePickerDirSubmit" or "SavePickerDirSubmit"
	local scrollKey = isOpen and "filePickerScroll" or "savePickerScroll"
	local scrollUpMsg = isOpen and "FilePickerScrollUp" or "SavePickerScrollUp"
	local scrollDownMsg = isOpen and "FilePickerScrollDown" or "SavePickerScrollDown"
	local scrollOffset = self[scrollKey]

	local currentPath = self[pathKey]
	local currentDir = self[dirKey]
	local entries = self[entriesKey]

	local displayValue = currentPath
	if focusedId == inputId then
		displayValue = displayValue:sub(1, cursorPos) .. "|" .. displayValue:sub(cursorPos + 1)
	else
		displayValue = #displayValue > 0 and displayValue or " "
	end

	local dirDisplay = currentDir
	if focusedId == dirInputId then
		dirDisplay = dirDisplay:sub(1, cursorPos) .. "|" .. dirDisplay:sub(cursorPos + 1)
	else
		dirDisplay = #dirDisplay > 0 and dirDisplay or " "
	end

	local focusBorderColor = { r = 0.3, g = 0.5, b = 1, a = 1 }
	local inputBorder = focusedId == inputId and {
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

	local dirInputBorder = focusedId == dirInputId and {
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

	-- Build file tree (scrollable)
	local fileListChildren = {}
	local totalEntries = #entries
	local canScrollUp = scrollOffset > 0
	local canScrollDown = scrollOffset + VISIBLE_ENTRIES < totalEntries

	-- Scroll up button (always shown, grayed out when at top)
	local upBg = canScrollUp and { r = 0.85, g = 0.88, b = 0.92, a = 1.0 } or { r = 0.92, g = 0.92, b = 0.95, a = 1.0 }
	local upFg = canScrollUp and { r = 0.2, g = 0.2, b = 0.2, a = 1 } or { r = 0.7, g = 0.7, b = 0.7, a = 1 }
	fileListChildren[#fileListChildren + 1] = Element.new("div")
		:withStyle({
			height = { abs = 16 },
			direction = "row",
			align = "center",
			justify = "center",
			bg = upBg
		})
		:onClick({ type = scrollUpMsg })
		:withChildren({ Element.from("^"):withStyle({ height = { abs = 12 }, fg = upFg }) })

	-- Parent directory ".."
	local parentDir = path.dirname(currentDir)
	if parentDir ~= currentDir then
		fileListChildren[#fileListChildren + 1] = Element.new("div")
			:withStyle({
				height = { abs = 22 },
				direction = "row",
				align = "center",
				padding = { left = 8 },
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 }
			})
			:onClick({ type = navMsg, value = parentDir })
			:withChildren({ Element.from(".. (parent)"):withStyle({ height = { abs = 14 } }) })
	end

	-- Visible entries (scroll window)
	local endIdx = math.min(scrollOffset + VISIBLE_ENTRIES, totalEntries)
	local shownCount = 0
	for i = scrollOffset + 1, endIdx do
		local entry = entries[i]

		local fullPath = path.join(currentDir, entry.name)
		local isDir = entry.type == "dir"
		local label = isDir and (entry.name .. "/") or entry.name

		local row
		if isDir then
			row = Element.new("div")
				:withStyle({
					height = { abs = 22 },
					direction = "row",
					align = "center",
					padding = { left = 8 },
					bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 }
				})
				:onClick({ type = navMsg, value = fullPath })
		else
			local isSelected = currentPath == fullPath
			row = Element.new("div")
				:withStyle({
					height = { abs = 22 },
					direction = "row",
					align = "center",
					padding = { left = 8 },
					bg = isSelected and { r = 0.7, g = 0.8, b = 1, a = 1.0 } or { r = 1, g = 1, b = 1, a = 1.0 }
				})
				:onClick({ type = fileClickMsg, value = fullPath })
		end

		row:withChildren({ Element.from(label):withStyle({ height = { abs = 14 } }) })
		fileListChildren[#fileListChildren + 1] = row
		shownCount = shownCount + 1
	end

	-- Scroll down button (always shown, grayed out when at bottom)
	local downBg = canScrollDown and { r = 0.85, g = 0.88, b = 0.92, a = 1.0 } or
		{ r = 0.92, g = 0.92, b = 0.95, a = 1.0 }
	local downFg = canScrollDown and { r = 0.2, g = 0.2, b = 0.2, a = 1 } or { r = 0.7, g = 0.7, b = 0.7, a = 1 }
	fileListChildren[#fileListChildren + 1] = Element.new("div")
		:withStyle({
			height = { abs = 16 },
			direction = "row",
			align = "center",
			justify = "center",
			bg = downBg
		})
		:onClick({ type = scrollDownMsg })
		:withChildren({ Element.from("v"):withStyle({ height = { abs = 12 }, fg = downFg }) })

	-- Total count label
	if totalEntries > 0 then
		local showingTo = math.min(scrollOffset + VISIBLE_ENTRIES, totalEntries)
		fileListChildren[#fileListChildren + 1] = Element.new("div")
			:withStyle({ height = { abs = 14 }, align = "center", justify = "center" })
			:withChildren({ Element.from(" " .. (scrollOffset + 1) .. "-" .. showingTo .. " of " .. totalEntries)
				:withStyle({ height = { abs = 11 } }) })
	end

	local title = isOpen and "Open File" or "Save As"
	local actionBtnLabel = isOpen and "Open" or "Save"

	return Element.new("div")
		:withStyle({ direction = "column", bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 } })
		:withChildren({
			-- Title bar
			Element.new("div")
				:withStyle({
					height = { abs = 28 },
					direction = "row",
					align = "center",
					padding = { left = 5 },
					border = { bottom = { width = 1, color = borderColor } }
				})
				:withChildren({ Element.from(title) }),
			-- Directory path bar with home button
			Element.new("div")
				:withStyle({
					height = { abs = 24 },
					direction = "row",
					align = "center",
					padding = { left = 4, right = 4 },
					bg = { r = 0.9, g = 0.9, b = 0.95, a = 1.0 },
					border = { bottom = { width = 1, color = borderColor } },
					gap = 4
				})
				:withChildren({
					-- Home button (~)
					Element.new("div")
						:withStyle({
							width = { abs = 20 },
							height = { abs = 20 },
							align = "center",
							justify = "center",
							bg = { r = 0.8, g = 0.85, b = 0.95, a = 1.0 },
							border = {
								top = { width = 1, color = borderColor },
								bottom = { width = 1, color = borderColor },
								left = { width = 1, color = borderColor },
								right = { width = 1, color = borderColor }
							}
						})
						:onClick({ type = navMsg, value = expandHome("~") })
						:withChildren({ Element.from("~") }),
					-- Editable directory path
					Element.new("div")
						:withStyle({
							height = { abs = 20 },
							direction = "row",
							bg = { r = 1, g = 1, b = 1, a = 1 },
							border = dirInputBorder,
							padding = { left = 3 },
							align = "center",
							width = { rel = 1.0 }
						})
						:asTextInput({
							id = dirInputId,
							value = currentDir,
							onsubmit = function(v) return { type = dirSubmitMsg, value = v } end
						})
						:withChildren({
							Element.from(dirDisplay):withStyle({ height = { abs = 13 } })
						})
				}),
			-- File list
			Element.new("div")
				:withStyle({
					height = "auto",
					direction = "column",
					bg = { r = 1, g = 1, b = 1, a = 1 },
					border = { bottom = { width = 1, color = borderColor } }
				})
				:withChildren(fileListChildren),
			-- Bottom: path input + buttons (fixed height so file list gets remaining space)
			Element.new("div")
				:withStyle({
					height = { abs = 68 },
					padding = { left = 6, right = 6, top = 6, bottom = 6 },
					direction = "column",
					gap = 4
				})
				:withChildren({
					-- Path input
					Element.new("div")
						:withStyle({
							height = { abs = 24 },
							direction = "row",
							bg = { r = 1, g = 1, b = 1, a = 1 },
							border = inputBorder,
							padding = { left = 4 },
							align = "center"
						})
						:asTextInput({
							id = inputId,
							value = currentPath,
							oninput = function(v) return { type = changeMsg, value = v } end,
							onsubmit = function(v) return { type = submitMsg, value = v } end
						})
						:withChildren({
							Element.from(displayValue):withStyle({ height = { abs = 13 } })
						}),
					-- Buttons
					Element.new("div")
						:withStyle({
							height = { abs = 28 },
							direction = "row",
							align = "center",
							justify = "end",
							gap = 8
						})
						:withChildren({
							Element.from("Cancel")
								:withStyle({
									width = { abs = 70 },
									height = { abs = 24 },
									align = "center",
									justify = "center",
									bg = { r = 0.9, g = 0.9, b = 0.9, a = 1 },
									border = {
										top = { width = 1, color = borderColor },
										bottom = { width = 1, color = borderColor },
										left = { width = 1, color = borderColor },
										right = { width = 1, color = borderColor }
									}
								})
								:onClick({ type = closeMsg }),
							Element.from(actionBtnLabel)
								:withStyle({
									width = { abs = 70 },
									height = { abs = 24 },
									align = "center",
									justify = "center",
									bg = { r = 0.3, g = 0.5, b = 1, a = 1 },
									border = {
										top = { width = 1, color = { r = 0.2, g = 0.4, b = 0.9, a = 1 } },
										bottom = { width = 1, color = { r = 0.2, g = 0.4, b = 0.9, a = 1 } },
										left = { width = 1, color = { r = 0.2, g = 0.4, b = 0.9, a = 1 } },
										right = { width = 1, color = { r = 0.2, g = 0.4, b = 0.9, a = 1 } }
									}
								})
								:onClick({ type = submitMsg, value = currentPath })
						})
				})
		})
end

---@param window winit.Window
function App:canvasSizePickerView(window)
	local borderColor = { r = 0.75, g = 0.75, b = 0.78, a = 1 }
	local focusedId = self.plugins.layout:getFocusedId(window)
	local cursorPos = self.plugins.layout:getCursorPos(window)
	local accentColor = { r = 0.3, g = 0.5, b = 1, a = 1 }
	local labelColor = { r = 0.45, g = 0.45, b = 0.5, a = 1 }

	local function makeInput(id, value, oninput)
		local isFocused = focusedId == id
		local displayValue = value
		if isFocused then
			displayValue = displayValue:sub(1, cursorPos) .. "|" .. displayValue:sub(cursorPos + 1)
		else
			displayValue = #displayValue > 0 and displayValue or " "
		end

		local inputBorder = isFocused and {
			top    = { width = 2, color = accentColor },
			bottom = { width = 2, color = accentColor },
			left   = { width = 2, color = accentColor },
			right  = { width = 2, color = accentColor }
		} or {
			top    = { width = 1, color = borderColor },
			bottom = { width = 1, color = borderColor },
			left   = { width = 1, color = borderColor },
			right  = { width = 1, color = borderColor }
		}

		return Element.new("div")
			:withStyle({
				height = { abs = 32 },
				bg = { r = 1, g = 1, b = 1, a = 1 },
				border = inputBorder,
				padding = { left = 8 },
				align = "center"
			})
			:asTextInput({
				id = id,
				value = value,
				oninput = oninput,
				onsubmit = function() return { type = "CanvasSizeSubmit" } end
			})
			:withChildren({
				Element.from(displayValue):withStyle({ height = { abs = 14 } })
			})
	end

	local function makeField(label, id, value, oninput)
		return Element.new("div")
			:withStyle({ direction = "column", gap = 5, height = "auto", width = "auto" })
			:withChildren({
				Element.from(label):withStyle({ height = { abs = 12 }, fg = labelColor }),
				makeInput(id, value, oninput)
			})
	end

	return Element.new("div")
		:withStyle({ direction = "column", bg = { r = 0.97, g = 0.97, b = 0.98, a = 1.0 } })
		:withChildren({
			-- Fields
			Element.new("div")
				:withStyle({
					height = "auto",
					padding = { top = 18, bottom = 18, left = 16, right = 16 },
					direction = "row",
					gap = 12
				})
				:withChildren({
					makeField("WIDTH", "canvasWidth", self.canvasWidthInput, function(v)
						return { type = "CanvasWidthChanged", value = v }
					end),
					makeField("HEIGHT", "canvasHeight", self.canvasHeightInput, function(v)
						return { type = "CanvasHeightChanged", value = v }
					end)
				}),
			-- Footer
			Element.new("div")
				:withStyle({
					height = { abs = 46 },
					direction = "row",
					align = "center",
					justify = "space-between",
					padding = { left = 14, right = 14 },
					border = { top = { width = 1, color = borderColor } },
					bg = { r = 0.93, g = 0.93, b = 0.95, a = 1.0 }
				})
				:withChildren({
					Element.from("Cancel")
						:withStyle({
							width = { abs = 72 },
							height = { abs = 28 },
							align = "center",
							justify = "center",
							fg = { r = 0.3, g = 0.3, b = 0.35, a = 1 },
							border = {
								top    = { width = 1, color = borderColor },
								bottom = { width = 1, color = borderColor },
								left   = { width = 1, color = borderColor },
								right  = { width = 1, color = borderColor }
							},
							bg = { r = 1, g = 1, b = 1, a = 1 }
						})
						:onClick({ type = "CanvasSizePopupClosed" }),
					Element.from("Apply")
						:withStyle({
							width = { abs = 72 },
							height = { abs = 28 },
							align = "center",
							justify = "center",
							fg = { r = 1, g = 1, b = 1, a = 1 },
							bg = accentColor
						})
						:onClick({ type = "CanvasSizeSubmit" })
				})
		})
end

---@param window winit.Window
function App:view(window)
	if window.kind == "Canvas Size" then
		return self:canvasSizePickerView(window)
	end
	if window.kind == "Open File" then
		return self:filePickerView(window, "open")
	end
	if window.kind == "Save File" then
		return self:filePickerView(window, "save")
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

	local canvasSizeLabel = self.resources.canvasWidth .. " x " .. self.resources.canvasHeight

	local statusBar = Element.new("div")
		:withStyle({
			height = { abs = 30 },
			width = "auto",
			direction = "row",
			align = "center",
			justify = "space-between",
			border = { top = { width = 1, color = borderColor } }
		})
		:withChildren({
			Element.from("arisu v0.5.0"):withStyle({
				width = { abs = 120 },
				align = "center",
				padding = { left = 10 }
			}),
			Element.from(canvasSizeLabel)
				:withStyle({
					width = { abs = 120 },
					align = "center",
					padding = { right = 10 }
				})
				:onClick({ type = "CanvasSizeClicked" })
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
				Element.new("div")
					:withStyle({
						height = { abs = 20 },
						width = { rel = 1.0 },
						align = "center",
						justify = "center"
					})
					:withChildren({ Element.from("<") })
					:onClick({ type = "RibbonToggled" }),
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

		local ribbonEl = self.ribbonOpen and sidebar or Element.new("div")
			:withStyle({
				direction = "column",
				width = { abs = 24 },
				height = { rel = 1.0 },
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
				border = { right = { width = 1, color = borderColor } },
				align = "center",
				padding = { top = 4 }
			})
			:withChildren({
				Element.new("div")
					:withStyle({ height = { abs = 20 }, width = { rel = 1.0 }, align = "center", justify = "center" })
					:withChildren({ Element.from(">") })
					:onClick({ type = "RibbonToggled" })
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
					:withChildren({ ribbonEl, makeCanvasArea({ rel = 1.0 }, "auto") }),
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
					}),
				Element.new("div")
					:withStyle({
						width = { abs = 24 },
						height = { rel = 1.0 },
						align = "center",
						justify = "center",
						border = { left = { width = 1, color = borderColor } }
					})
					:withChildren({ Element.from("^") })
					:onClick({ type = "RibbonToggled" })
			})

		local ribbonEl = self.ribbonOpen and toolbar or Element.new("div")
			:withStyle({
				height = { abs = 24 },
				direction = "row",
				align = "center",
				justify = "center",
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 },
				border = { bottom = { width = 1, color = borderColor } }
			})
			:withChildren({
				Element.new("div")
					:withStyle({ width = { abs = 24 }, height = { rel = 1.0 }, align = "center", justify = "center" })
					:withChildren({ Element.from("v") })
					:onClick({ type = "RibbonToggled" })
			})

		return Element.new("div")
			:withStyle({
				direction = "column",
				bg = { r = 0.95, g = 0.95, b = 0.95, a = 1.0 }
			})
			:withChildren({ menuBar, ribbonEl, makeCanvasArea("auto"), statusBar })
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

			local W, H = self.resources.canvasWidth, self.resources.canvasHeight
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

	if event.name == "mouseScroll" then
		if event.window.kind == "Open File" then
			local maxScroll = math.max(0, #self.filePickerEntries - VISIBLE_ENTRIES)
			local step = event.dy > 0 and 3 or -3
			self.filePickerScroll = math.max(0, math.min(maxScroll, self.filePickerScroll + step))
			self.plugins.ui:refreshView(event.window)
			return nil
		elseif event.window.kind == "Save File" then
			local maxScroll = math.max(0, #self.savePickerEntries - VISIBLE_ENTRIES)
			local step = event.dy > 0 and 3 or -3
			self.savePickerScroll = math.max(0, math.min(maxScroll, self.savePickerScroll + step))
			self.plugins.ui:refreshView(event.window)
			return nil
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
		-- Load directory listing when opening the file picker
		self.filePickerDir = "."
		self.filePickerEntries = self:listDir(self.filePickerDir)
		self.filePickerScroll = 0
		return { type = "createWindow", width = 500, height = 350, kind = "Open File" }
	elseif message.type == "OpenPopupClosed" then
		self.filePickerPath = ""
		return { type = "closeWindow" }
	elseif message.type == "FilePathChanged" then
		self.filePickerPath = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "FilePickerNavigate" then
		self.filePickerDir = message.value
		self.filePickerEntries = self:listDir(self.filePickerDir)
		self.filePickerScroll = 0
		self.filePickerPath = ""
		self.plugins.ui:refreshView(window)
	elseif message.type == "FileEntryClicked" then
		self.filePickerPath = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "SavePickerNavigate" then
		self.savePickerDir = message.value
		self.savePickerEntries = self:listDir(self.savePickerDir)
		self.savePickerScroll = 0
		self.saveFilePath = ""
		self.plugins.ui:refreshView(window)
	elseif message.type == "SaveEntryClicked" then
		self.saveFilePath = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "FilePathSubmit" then
		if window.kind == "Open File" then
			local rawPath = message.value
			if rawPath and #rawPath > 0 then
				local resolved = expandHome(rawPath)
				if resolved:sub(1, 1) ~= "/" then
					resolved = path.join(self.filePickerDir, resolved)
				end
				local img, err = Image.fromPath(resolved)
				if img then
					local w, h = img.width, img.height
					if w > 1024 or h > 1024 then
						print("Image too large (max 1024x1024): " .. w .. "x" .. h)
					elseif w > 0 and h > 0 then
						local textureManager = self.plugins.render.sharedResources.textureManager
						local device = self.plugins.render.device

						-- Convert RGB to RGBA if needed (GPU uses 4 channels)
						local pixels = img.pixels
						if img.channels == 3 then
							local rgbaPixels = ffi.new("uint8_t[?]", w * h * 4)
							local srcPos = 0
							local dstPos = 0
							for _ = 0, w * h - 1 do
								rgbaPixels[dstPos]     = pixels[srcPos]
								rgbaPixels[dstPos + 1] = pixels[srcPos + 1]
								rgbaPixels[dstPos + 2] = pixels[srcPos + 2]
								rgbaPixels[dstPos + 3] = 255
								srcPos                 = srcPos + 3
								dstPos                 = dstPos + 4
							end
							pixels = rgbaPixels
						end

						-- Allocate new canvas and upload pixels
						local canvas = textureManager:allocate(w, h)
						device.queue:writeTexture(
							textureManager.texture,
							{ layer = canvas, width = w, height = h },
							pixels
						)

						-- Update canvas resources
						self.resources.textures.canvas = canvas
						self.resources.canvasWidth = w
						self.resources.canvasHeight = h
						self.resources.compute = Compute.new(textureManager, canvas, device)
						self.plugins.overlay:resize(self.plugins.window.mainCtx.window, w, h)
						self.plugins.ui:refreshView(self.plugins.window.mainCtx.window)

						print("Opened file: " .. resolved .. " (" .. w .. "x" .. h .. ")")
					end
				else
					print("Failed to open file: " .. (err or "unknown error"))
				end
			end
			self.filePickerPath = ""
			return { type = "closeWindow" }
		elseif window.kind == "Save File" then
			local rawPath = message.value
			if rawPath and #rawPath > 0 then
				local resolved = expandHome(rawPath)
				if resolved:sub(1, 1) ~= "/" then
					resolved = path.join(self.savePickerDir, resolved)
				end
				local cw, ch = self.resources.canvasWidth, self.resources.canvasHeight
				local textureManager = self.plugins.render.sharedResources.textureManager
				local device = self.plugins.render.device

				-- Read canvas pixels from GPU
				local bufferSize = cw * ch * 4
				local readBuffer = device:createBuffer({ size = bufferSize, usages = { "COPY_DST", "MAP_READ" } })

				local encoder = device:createCommandEncoder()
				encoder:copyTextureToBuffer(
					{ texture = textureManager.texture, origin = { x = 0, y = 0, z = self.resources.textures.canvas } },
					{ buffer = readBuffer, bytesPerRow = cw * 4 },
					{ width = cw, height = ch, depthOrArrayLayers = 1 }
				)
				device.queue:submit(encoder:finish())
				device.queue:waitIdle()

				readBuffer:mapAsync()
				local pixels = ffi.cast("uint8_t*", readBuffer:getMappedRange())

				-- Encode as QOI and write to file
				local encoded = QOI.Encode(cw, ch, 4, pixels)
				readBuffer:unmap()
				readBuffer:destroy()

				local file, err = io.open(resolved, "wb")
				if file then
					file:write(encoded)
					file:close()
					print("Saved file: " .. resolved .. " (" .. cw .. "x" .. ch .. ")")
				else
					print("Failed to save file: " .. (err or "unknown error"))
				end
			end
			self.saveFilePath = ""
			return { type = "closeWindow" }
		end
	elseif message.type == "SaveClicked" then
		self.savePickerDir = "."
		self.savePickerEntries = self:listDir(self.savePickerDir)
		self.savePickerScroll = 0
		return { type = "createWindow", width = 500, height = 350, kind = "Save File" }
	elseif message.type == "SavePopupClosed" then
		self.saveFilePath = ""
		return { type = "closeWindow" }
	elseif message.type == "SaveFilePathChanged" then
		self.saveFilePath = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "FilePickerDirSubmit" then
		local dir = expandHome(message.value)
		if fs.isdir(dir) then
			self.filePickerDir = dir
			self.filePickerEntries = self:listDir(dir)
			self.filePickerScroll = 0
			self.filePickerPath = ""
			self.plugins.ui:refreshView(window)
		elseif fs.isfile(dir) then
			local parent = path.dirname(dir)
			if fs.isdir(parent) then
				self.filePickerDir = parent
				self.filePickerEntries = self:listDir(parent)
				self.filePickerScroll = 0
				self.filePickerPath = dir
				self.plugins.ui:refreshView(window)
			end
		end
	elseif message.type == "SavePickerDirSubmit" then
		local dir = expandHome(message.value)
		if fs.isdir(dir) then
			self.savePickerDir = dir
			self.savePickerEntries = self:listDir(dir)
			self.savePickerScroll = 0
			self.saveFilePath = ""
			self.plugins.ui:refreshView(window)
		elseif fs.isfile(dir) then
			local parent = path.dirname(dir)
			if fs.isdir(parent) then
				self.savePickerDir = parent
				self.savePickerEntries = self:listDir(parent)
				self.savePickerScroll = 0
				self.saveFilePath = dir
				self.plugins.ui:refreshView(window)
			end
		end
	elseif message.type == "FilePickerScrollUp" then
		self.filePickerScroll = math.max(0, self.filePickerScroll - 1)
		self.plugins.ui:refreshView(window)
	elseif message.type == "FilePickerScrollDown" then
		local maxScroll = math.max(0, #self.filePickerEntries - VISIBLE_ENTRIES)
		self.filePickerScroll = math.min(maxScroll, self.filePickerScroll + 1)
		self.plugins.ui:refreshView(window)
	elseif message.type == "SavePickerScrollUp" then
		self.savePickerScroll = math.max(0, self.savePickerScroll - 1)
		self.plugins.ui:refreshView(window)
	elseif message.type == "SavePickerScrollDown" then
		local maxScroll = math.max(0, #self.savePickerEntries - VISIBLE_ENTRIES)
		self.savePickerScroll = math.min(maxScroll, self.savePickerScroll + 1)
		self.plugins.ui:refreshView(window)
	elseif message.type == "RibbonToggled" then
		self.ribbonOpen = not self.ribbonOpen
		self.plugins.ui:refreshView(window)
	elseif message.type == "BrushesToggled" then
		self.brushesOpen = not self.brushesOpen
		self.plugins.ui:refreshView(window)
	elseif message.type == "BrushSizeSelected" then
		self.brushSize = message.size
		self.brushesOpen = false
		self.plugins.ui:refreshView(window)
	elseif message.type == "CanvasSizeClicked" then
		self.canvasWidthInput = tostring(self.resources.canvasWidth)
		self.canvasHeightInput = tostring(self.resources.canvasHeight)
		return { type = "createWindow", width = 340, height = 180, kind = "Canvas Size" }
	elseif message.type == "CanvasSizePopupClosed" then
		self.canvasWidthInput = ""
		self.canvasHeightInput = ""
		return { type = "closeWindow" }
	elseif message.type == "CanvasWidthChanged" then
		self.canvasWidthInput = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "CanvasHeightChanged" then
		self.canvasHeightInput = message.value
		self.plugins.ui:refreshView(window)
	elseif message.type == "CanvasSizeSubmit" then
		local newWidth = tonumber(self.canvasWidthInput)
		local newHeight = tonumber(self.canvasHeightInput)
		if newWidth and newHeight and newWidth > 0 and newHeight > 0
			and newWidth <= 1024 and newHeight <= 1024 then
			local w, h = math.floor(newWidth), math.floor(newHeight)
			local textureManager = self.plugins.render.sharedResources.textureManager
			local canvas = textureManager:allocate(w, h)
			self.resources.textures.canvas = canvas
			self.resources.canvasWidth = w
			self.resources.canvasHeight = h
			self.resources.compute = Compute.new(textureManager, canvas, self.plugins.render.device)
			self.plugins.overlay:resize(self.plugins.window.mainCtx.window, w, h)
			self.plugins.ui:refreshView(self.plugins.window.mainCtx.window)
		end
		self.canvasWidthInput = ""
		self.canvasHeightInput = ""
		return { type = "closeWindow" }
	end
end

Arisu.run(App)
