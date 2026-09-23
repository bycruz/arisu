local build = require("lde-build")

local sep = string.sub(package.config, 1, 1)

--- hood's opengl backend compiles GLSL itself, so it takes the source text,
--- while vulkan takes SPIR-V. The runtime picks the module flavor off the same
--- variable, so a build has to agree with the run.
local isVulkan = os.getenv("VULKAN") and true or false

local escapes = {
	[34] = '\\"',
	[92] = "\\\\",
	[9] = "\\t",
	[10] = "\\n",
	[13] = "\\r"
}

--- Escapes quotes, backslashes and control characters so that both GLSL source
--- and binary SPIR-V survive as a Lua string literal. Numeric escapes are
--- always three digits wide, otherwise "\10" followed by a literal digit byte
--- would be read back as a single character.
---@param data string
---@return string
local function toLuaLiteral(data)
	return (data:gsub("[%z\1-\31\\\"]", function(char)
		return escapes[char:byte()] or string.format("\\%03d", char:byte())
	end))
end

--- The shader sources live in src/, so lde hands them to this script inside
--- the output dir. `name` is the source's file base and its dots become
--- directories: overlay.vert.glsl becomes shaders/overlay/vert/glsl.lua,
--- required as arisu.shaders.overlay.vert.glsl (or .spv under vulkan).
---
--- Both flavors are written under vulkan so the same build also runs on
--- opengl. SPIR-V is compiled on every build: lde only hashes src/, lde.json
--- and build.lua, so reusing a previously compiled .spv would ship a stale
--- shader after an edit, and shaders are tiny anyway.
---@param name string # base of the .glsl file, e.g. "overlay.vert"
---@param stage "vert" | "frag" | "comp" # glslc stage; its name for a compute shader is "comp"
local function embedShader(name, stage)
	local source = "shaders" .. sep .. name
	local module = "shaders" .. sep .. (name:gsub("%.", sep))
	local flavors = { "glsl" }

	if isVulkan then
		build:sh(string.format('glslc -fshader-stage=%s "%s.glsl" -o "%s.spv"', stage, source, source))
		flavors[#flavors + 1] = "spv"
	end

	for _, flavor in ipairs(flavors) do
		local content = build:read(source .. "." .. flavor)
		build:write(module .. sep .. flavor .. ".lua", 'return "' .. toLuaLiteral(content) .. '"')
	end

	-- The compiled SPIR-V is an intermediate: only the module above ships.
	if isVulkan then
		build:delete(source .. ".spv")
	end
end

embedShader("overlay.vert", "vert")
embedShader("overlay.frag", "frag")
embedShader("brush.compute", "comp")

--- The assets are raw data (qoi, wav), so each one becomes the module of the
--- same path with its extension swapped: icons/brush.qoi turns into
--- icons/brush.lua, required as arisu.assets.icons.brush.
for _, file in ipairs(build:scan("assets")) do
	local content = build:read(file)
	build:write((file:gsub("%.[^%.]+$", "")) .. ".lua", 'return "' .. toLuaLiteral(content) .. '"')
end
