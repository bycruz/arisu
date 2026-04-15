local pathSep = string.sub(package.config, 1, 1)

---@type string
local arisuDir = debug.getinfo(1, "S").source:sub(2):match("(.*)" .. pathSep)

---@param stage "vert" | "frag" | "comp"
---@param glslPath string
---@param outputPath string
local function glslToSpirv(stage, glslPath, outputPath)
	local command = string.format("glslc -fshader-stage=%s %s -o %s", stage, glslPath, outputPath)

	local result = os.execute(command)
	if result ~= 0 then
		error("Failed to compile GLSL shader: " .. glslPath)
	end
end

---@param path string
local function exists(path)
	local handle = io.open(path, "r")
	if handle then
		handle:close()
		return true
	end

	return false
end

if os.getenv("VULKAN") then
	local inputVertex = arisuDir .. "/shaders/overlay.vert.glsl"
	local outputVertex = arisuDir .. "/shaders/overlay.vert.spv"
	if not exists(outputVertex) then
		print("SPIR-V vertex shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("vert", inputVertex, outputVertex)
	end

	local inputFragment = arisuDir .. "/shaders/overlay.frag.glsl"
	local outputFragment = arisuDir .. "/shaders/overlay.frag.spv"
	if not exists(outputFragment) then
		print("SPIR-V fragment shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("frag", inputFragment, outputFragment)
	end

	local inputCompute = arisuDir .. "/shaders/brush.compute.glsl"
	local outputCompute = arisuDir .. "/shaders/brush.compute.spv"
	if not exists(outputCompute) then
		print("SPIR-V compute shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("comp", inputCompute, outputCompute)
	end
end

-- Output assets as lua files that can be used with require() in final target folder.

local outputDir = os.getenv("LDE_OUTPUT_DIR")

local function read(path)
	local handle = io.open(path, "rb")
	if handle then
		local r = handle:read("*a")
		handle:close()
		return r
	end
end

local function write(path, content)
	local handle = io.open(path, "wb")
	if handle then
		handle:write(content)
		handle:close()
	end
end

local function toLuaStringLiteral(data)
	return (data:gsub(".", function(c)
		local b = c:byte()
		if b >= 32 and b <= 126 and c ~= '"' and c ~= "\\" then
			return c
		end
		return string.format("\\x%02x", b)
	end))
end

local function mkdirp(path)
	if not exists(path) then
		if jit.os == "Windows" then
			os.execute(string.format('mkdir "%s"', path))
		else
			os.execute(string.format("mkdir -p %q", path))
		end
	end
end

-- Shaders (flat)
local shaderSrcDir = arisuDir .. "/shaders"
local shaderOutDir = outputDir .. "/shaders"
mkdirp(shaderOutDir)

local shaderListCmd
if jit.os == "Windows" then
	shaderListCmd = string.format('dir /b "%s"', shaderSrcDir)
else
	shaderListCmd = string.format("ls %q", shaderSrcDir)
end

local shaderHandle = io.popen(shaderListCmd)
if shaderHandle then
	for filename in shaderHandle:lines() do
		local content = read(shaderSrcDir .. "/" .. filename)
		if content then
			write(shaderOutDir .. "/" .. filename .. ".lua", string.format('return "%s"\n', toLuaStringLiteral(content)))
		end
	end
	shaderHandle:close()
end

-- Assets (recursive)
local assetsSrcDir = arisuDir .. "/assets"
local assetsListCmd
if jit.os == "Windows" then
	assetsListCmd = string.format('dir /s /b "%s"', assetsSrcDir)
else
	assetsListCmd = string.format("find %q -type f", assetsSrcDir)
end

local assetsHandle = io.popen(assetsListCmd)
if assetsHandle then
	for srcPath in assetsHandle:lines() do
		local relPath = srcPath:sub(#arisuDir + 2)
		local outPath = outputDir .. "/" .. relPath .. ".lua"
		mkdirp(outPath:match("(.*)" .. pathSep))
		local content = read(srcPath)
		if content then
			write(outPath, string.format('return "%s"\n', toLuaStringLiteral(content)))
		end
	end
	assetsHandle:close()
end
