local outputDir = os.getenv("LDE_OUTPUT_DIR")

local pathSep = string.sub(package.config, 1, 1)

---@type string
local packageSourceDir = debug.getinfo(1, "S").source:sub(2):match("(.*)" .. pathSep)

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

---@param path string
local function read(path)
	local handle = io.open(path, "rb")
	if handle then
		local r = handle:read("*a")
		handle:close()
		return r
	end
end

---@param path string
local function write(path, content)
	local handle = io.open(path, "wb")
	if handle then
		handle:write(content)
		handle:close()
	end
end

if os.getenv("VULKAN") then
	local inputVertex = packageSourceDir .. "/shaders/main.vert.glsl"
	local outputVertex = packageSourceDir .. "/shaders/main.vert.spv"
	if not exists(outputVertex) then
		print("SPIR-V vertex shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("vert", inputVertex, outputVertex)
	end

	local inputFragment = packageSourceDir .. "/shaders/main.frag.glsl"
	local outputFragment = packageSourceDir .. "/shaders/main.frag.spv"
	if not exists(outputFragment) then
		print("SPIR-V fragment shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("frag", inputFragment, outputFragment)
	end
end

-- Write shader files as Lua modules to output dir

local shaderSrcDir = packageSourceDir .. "/shaders"
local shaderOutDir = outputDir .. "/shaders"

if not exists(shaderOutDir) then
	if jit.os == "Windows" then
		os.execute(string.format('mkdir "%s"', shaderOutDir))
	else
		os.execute(string.format("mkdir -p %q", shaderOutDir))
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
			local outRelPath = filename:gsub("%.", pathSep)
			local outPath = shaderOutDir .. pathSep .. outRelPath .. ".lua"
			mkdirp(outPath:match("(.*)" .. pathSep))
			write(outPath, string.format('return "%s"\n', toLuaStringLiteral(content)))
		end
	end
	shaderHandle:close()
end

local assetsSrcDir = packageSourceDir .. "/assets"
local assetsListCmd
if jit.os == "Windows" then
	assetsListCmd = string.format('dir /s /b "%s"', assetsSrcDir)
else
	assetsListCmd = string.format("find %q -type f", assetsSrcDir)
end

local assetsHandle = io.popen(assetsListCmd)
if assetsHandle then
	for srcPath in assetsHandle:lines() do
		local relPath = srcPath:sub(#packageSourceDir + 2)
		local relPathNoExt = relPath:match("(.+)%.[^%.]+$") or relPath
		local outPath = outputDir .. pathSep .. relPathNoExt .. ".lua"
		mkdirp(outPath:match("(.*)" .. pathSep))

		local content = read(srcPath)
		if content and not exists(outPath) then
			write(outPath, string.format('return "%s"\n', toLuaStringLiteral(content)))
		end
	end

	assetsHandle:close()
end
