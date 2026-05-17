local build = require("lde-build")

local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"

local libName = isWindows and "stbtt.dll" or (isMac and "libstbtt.dylib" or "libstbtt.so")

-- Download stb_truetype.h
build:write("stb_truetype.h", build:fetch(
	"https://raw.githubusercontent.com/nothings/stb/6e9f34d5429cf16790ec43c9bac3f1ee4ad1f760/stb_truetype.h"
))

-- Compile .h directly into a shared library (single-header library pattern).
-- -x c forces C compilation regardless of extension.
-- On Windows, STBTT_DEF is overridden with __declspec(dllexport) so symbols
-- are visible outside the DLL. On other platforms, extern is the default.
local ccFlags
if isWindows then
	ccFlags = string.format(
		'-x c -O2 -shared -o %s'
		.. ' -DSTBTT_DEF=__declspec(dllexport)'
		.. ' -DSTB_TRUETYPE_IMPLEMENTATION'
		.. ' -lm',
		libName
	)
else
	ccFlags = string.format(
		'-x c -O2 -fPIC %s -o %s'
		.. ' -DSTB_TRUETYPE_IMPLEMENTATION'
		.. ' -lm',
		isMac and "-dynamiclib" or "-shared",
		libName
	)
end

build:sh(string.format('cd "%s" && gcc %s stb_truetype.h', build.outDir, ccFlags))

-- Strip to reduce size (not needed on Windows with gcc)
if not isWindows then
	local stripFlags = isMac and "-x" or "--strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr"
	build:sh(string.format('strip %s "%s/%s"', stripFlags, build.outDir, libName))
end
