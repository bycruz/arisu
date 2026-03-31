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

-- Symlink source /shaders/ dir into target output dir

local targetShaderDir = outputDir .. "/shaders"
if not exists(targetShaderDir) then
	if jit.os == "Windows" then
		os.execute(string.format('mklink /J "%s" "%s"', targetShaderDir, packageSourceDir .. "/shaders"))
	else
		os.execute(string.format("ln -s %s %s", packageSourceDir .. "/shaders", targetShaderDir))
	end
end
