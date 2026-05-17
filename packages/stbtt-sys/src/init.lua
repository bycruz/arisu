---@meta stbtt-sys

local ffi = require("ffi")

ffi.cdef [[
typedef struct {
	unsigned char *data;
	int cursor;
	int size;
} stbtt__buf;

typedef struct {
	unsigned short x0,y0,x1,y1;
	float xoff,yoff,xadvance;
} stbtt_bakedchar;

typedef struct {
	float x0,y0,s0,t0;
	float x1,y1,s1,t1;
} stbtt_aligned_quad;

typedef struct {
	unsigned short x0,y0,x1,y1;
	float xoff,yoff,xadvance;
	float xoff2,yoff2;
} stbtt_packedchar;

typedef struct {
	void *userdata;
	unsigned char *data;
	int fontstart;
	int numGlyphs;
	int loca,head,glyf,hhea,hmtx,kern,gpos,svg;
	int index_map;
	int indexToLocFormat;
	stbtt__buf cff;
	stbtt__buf charstrings;
	stbtt__buf gsubrs;
	stbtt__buf subrs;
	stbtt__buf fontdicts;
	stbtt__buf fdselect;
} stbtt_fontinfo;

typedef struct stbtt_pack_context stbtt_pack_context;

typedef unsigned short stbtt_vertex_type;

typedef struct {
	stbtt_vertex_type x,y,cx,cy,cx1,cy1;
	unsigned char type, padding;
} stbtt_vertex;

typedef struct {
	int w,h,stride;
	unsigned char *pixels;
} stbtt__bitmap;

typedef struct {
	int glyph1;
	int glyph2;
	int advance;
} stbtt_kerningentry;

typedef int stbrp_coord;

struct stbtt_pack_context {
	void *user_allocator_context;
	void *pack_info;
	int width;
	int height;
	int stride_in_bytes;
	int padding;
	int skip_missing;
	unsigned int h_oversample, v_oversample;
	unsigned char *pixels;
	void *nodes;
};

typedef struct {
	float font_size;
	int first_unicode_codepoint_in_range;
	int *array_of_unicode_codepoints;
	int num_chars;
	stbtt_packedchar *chardata_for_range;
	unsigned char h_oversample, v_oversample;
} stbtt_pack_range;

struct stbrp_rect {
	stbrp_coord x,y;
	int id,w,h,was_packed;
};

int stbtt_BakeFontBitmap(const unsigned char *data, int offset,
	float pixel_height, unsigned char *pixels, int pw, int ph,
	int first_char, int num_chars, stbtt_bakedchar *chardata);
void stbtt_GetBakedQuad(const stbtt_bakedchar *chardata, int pw, int ph,
	int char_index, float *xpos, float *ypos,
	stbtt_aligned_quad *q, int opengl_fillrule);
void stbtt_GetScaledFontVMetrics(const unsigned char *fontdata, int index,
	float size, float *ascent, float *descent, float *lineGap);
int stbtt_PackBegin(stbtt_pack_context *spc, unsigned char *pixels,
	int width, int height, int stride_in_bytes, int padding, void *alloc_context);
void stbtt_PackEnd(stbtt_pack_context *spc);
int stbtt_PackFontRange(stbtt_pack_context *spc, const unsigned char *fontdata,
	int font_index, float font_size, int first_unicode_codepoint_in_range,
	int num_chars_in_range, stbtt_packedchar *chardata_for_range);
int stbtt_PackFontRanges(stbtt_pack_context *spc, const unsigned char *fontdata,
	int font_index, stbtt_pack_range *ranges, int num_ranges);
void stbtt_PackSetOversampling(stbtt_pack_context *spc,
	unsigned int h_oversample, unsigned int v_oversample);
void stbtt_PackSetSkipMissingCodepoints(stbtt_pack_context *spc, int skip);
void stbtt_GetPackedQuad(const stbtt_packedchar *chardata, int pw, int ph,
	int char_index, float *xpos, float *ypos,
	stbtt_aligned_quad *q, int align_to_integer);
int stbtt_PackFontRangesGatherRects(stbtt_pack_context *spc,
	const stbtt_fontinfo *info, stbtt_pack_range *ranges,
	int num_ranges, struct stbrp_rect *rects);
void stbtt_PackFontRangesPackRects(stbtt_pack_context *spc,
	struct stbrp_rect *rects, int num_rects);
int stbtt_PackFontRangesRenderIntoRects(stbtt_pack_context *spc,
	const stbtt_fontinfo *info, stbtt_pack_range *ranges,
	int num_ranges, struct stbrp_rect *rects);
int stbtt_GetNumberOfFonts(const unsigned char *data);
int stbtt_GetFontOffsetForIndex(const unsigned char *data, int index);
int stbtt_InitFont(stbtt_fontinfo *info, const unsigned char *data, int offset);
int stbtt_FindGlyphIndex(const stbtt_fontinfo *info, int unicode_codepoint);
float stbtt_ScaleForPixelHeight(const stbtt_fontinfo *info, float pixels);
float stbtt_ScaleForMappingEmToPixels(const stbtt_fontinfo *info, float pixels);
void stbtt_GetFontVMetrics(const stbtt_fontinfo *info, int *ascent, int *descent, int *lineGap);
int  stbtt_GetFontVMetricsOS2(const stbtt_fontinfo *info, int *typoAscent, int *typoDescent, int *typoLineGap);
void stbtt_GetFontBoundingBox(const stbtt_fontinfo *info, int *x0, int *y0, int *x1, int *y1);
void stbtt_GetCodepointHMetrics(const stbtt_fontinfo *info, int codepoint, int *advanceWidth, int *leftSideBearing);
int  stbtt_GetCodepointKernAdvance(const stbtt_fontinfo *info, int ch1, int ch2);
void stbtt_GetGlyphHMetrics(const stbtt_fontinfo *info, int glyph_index, int *advanceWidth, int *leftSideBearing);
int  stbtt_GetGlyphKernAdvance(const stbtt_fontinfo *info, int glyph1, int glyph2);
int  stbtt_GetCodepointBox(const stbtt_fontinfo *info, int codepoint, int *x0, int *y0, int *x1, int *y1);
int  stbtt_GetGlyphBox(const stbtt_fontinfo *info, int glyph_index, int *x0, int *y0, int *x1, int *y1);
int  stbtt_IsGlyphEmpty(const stbtt_fontinfo *info, int glyph_index);
int  stbtt_GetKerningTableLength(const stbtt_fontinfo *info);
int  stbtt_GetKerningTable(const stbtt_fontinfo *info, stbtt_kerningentry *table, int table_length);
int stbtt_GetCodepointShape(const stbtt_fontinfo *info, int unicode_codepoint, stbtt_vertex **vertices);
int stbtt_GetGlyphShape(const stbtt_fontinfo *info, int glyph_index, stbtt_vertex **vertices);
void stbtt_FreeShape(const stbtt_fontinfo *info, stbtt_vertex *vertices);
unsigned char *stbtt_FindSVGDoc(const stbtt_fontinfo *info, int gl);
int stbtt_GetCodepointSVG(const stbtt_fontinfo *info, int unicode_codepoint, const char **svg);
int stbtt_GetGlyphSVG(const stbtt_fontinfo *info, int gl, const char **svg);
void stbtt_FreeBitmap(unsigned char *bitmap, void *userdata);
unsigned char *stbtt_GetCodepointBitmap(const stbtt_fontinfo *info, float scale_x, float scale_y, int codepoint, int *width, int *height, int *xoff, int *yoff);
unsigned char *stbtt_GetCodepointBitmapSubpixel(const stbtt_fontinfo *info, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint, int *width, int *height, int *xoff, int *yoff);
void stbtt_MakeCodepointBitmap(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int codepoint);
void stbtt_MakeCodepointBitmapSubpixel(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int codepoint);
void stbtt_MakeCodepointBitmapSubpixelPrefilter(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int oversample_x, int oversample_y, float *sub_x, float *sub_y, int codepoint);
void stbtt_GetCodepointBitmapBox(const stbtt_fontinfo *font, int codepoint, float scale_x, float scale_y, int *ix0, int *iy0, int *ix1, int *iy1);
void stbtt_GetCodepointBitmapBoxSubpixel(const stbtt_fontinfo *font, int codepoint, float scale_x, float scale_y, float shift_x, float shift_y, int *ix0, int *iy0, int *ix1, int *iy1);
unsigned char *stbtt_GetGlyphBitmap(const stbtt_fontinfo *info, float scale_x, float scale_y, int glyph, int *width, int *height, int *xoff, int *yoff);
unsigned char *stbtt_GetGlyphBitmapSubpixel(const stbtt_fontinfo *info, float scale_x, float scale_y, float shift_x, float shift_y, int glyph, int *width, int *height, int *xoff, int *yoff);
void stbtt_MakeGlyphBitmap(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, int glyph);
void stbtt_MakeGlyphBitmapSubpixel(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int glyph);
void stbtt_MakeGlyphBitmapSubpixelPrefilter(const stbtt_fontinfo *info, unsigned char *output, int out_w, int out_h, int out_stride, float scale_x, float scale_y, float shift_x, float shift_y, int oversample_x, int oversample_y, float *sub_x, float *sub_y, int glyph);
void stbtt_GetGlyphBitmapBox(const stbtt_fontinfo *font, int glyph, float scale_x, float scale_y, int *ix0, int *iy0, int *ix1, int *iy1);
void stbtt_GetGlyphBitmapBoxSubpixel(const stbtt_fontinfo *font, int glyph, float scale_x, float scale_y, float shift_x, float shift_y, int *ix0, int *iy0, int *ix1, int *iy1);
void stbtt_Rasterize(stbtt__bitmap *result, float flatness_in_pixels,
	stbtt_vertex *vertices, int num_verts, float scale_x, float scale_y,
	float shift_x, float shift_y, int x_off, int y_off,
	int invert, void *userdata);
void stbtt_FreeSDF(unsigned char *bitmap, void *userdata);
unsigned char *stbtt_GetGlyphSDF(const stbtt_fontinfo *info, float scale,
	int glyph, int padding, unsigned char onedge_value,
	float pixel_dist_scale, int *width, int *height, int *xoff, int *yoff);
unsigned char *stbtt_GetCodepointSDF(const stbtt_fontinfo *info, float scale,
	int codepoint, int padding, unsigned char onedge_value,
	float pixel_dist_scale, int *width, int *height, int *xoff, int *yoff);
int stbtt_FindMatchingFont(const unsigned char *fontdata, const char *name, int flags);
int stbtt_CompareUTF8toUTF16_bigendian(const char *s1, int len1, const char *s2, int len2);
const char *stbtt_GetFontNameString(const stbtt_fontinfo *font, int *length,
	int platformID, int encodingID, int languageID, int nameID);

enum { STBTT_vmove=1, STBTT_vline, STBTT_vcurve, STBTT_vcubic };
enum { STBTT_PLATFORM_ID_UNICODE=0, STBTT_PLATFORM_ID_MAC=1, STBTT_PLATFORM_ID_ISO=2, STBTT_PLATFORM_ID_MICROSOFT=3 };
enum { STBTT_UNICODE_EID_UNICODE_1_0=0, STBTT_UNICODE_EID_UNICODE_1_1=1, STBTT_UNICODE_EID_ISO_10646=2, STBTT_UNICODE_EID_UNICODE_2_0_BMP=3, STBTT_UNICODE_EID_UNICODE_2_0_FULL=4 };
enum { STBTT_MS_EID_SYMBOL=0, STBTT_MS_EID_UNICODE_BMP=1, STBTT_MS_EID_SHIFTJIS=2, STBTT_MS_EID_UNICODE_FULL=10 };
enum { STBTT_MACSTYLE_DONTCARE=0, STBTT_MACSTYLE_BOLD=1, STBTT_MACSTYLE_ITALIC=2, STBTT_MACSTYLE_UNDERSCORE=4, STBTT_MACSTYLE_NONE=8 };

]]

-- Load the shared library
local here         = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or ""
local sep          = string.sub(package.config, 1, 1)
local libName      = sep == "\\" and "stbtt.dll" or
	(jit.os == "OSX" and "libstbtt.dylib" or "libstbtt.so")

---@class stbtt.Fns
---@field stbtt_BakeFontBitmap fun(data:ffi.cdata*, offset:integer, pixel_height:number, pixels:ffi.cdata*, pw:integer, ph:integer, first_char:integer, num_chars:integer, chardata:stbtt.ffi.BakedChar): integer
---@field stbtt_GetBakedQuad fun(chardata:stbtt.ffi.BakedChar, pw:integer, ph:integer, char_index:integer, xpos:ffi.cdata*, ypos:ffi.cdata*, q:stbtt.ffi.AlignedQuad, opengl_fillrule:integer)
---@field stbtt_GetScaledFontVMetrics fun(fontdata:ffi.cdata*, index:integer, size:number, ascent:ffi.cdata*, descent:ffi.cdata*, lineGap:ffi.cdata*)
---@field stbtt_PackBegin fun(spc:stbtt.ffi.PackContext, pixels:ffi.cdata*, width:integer, height:integer, stride_in_bytes:integer, padding:integer, alloc_context:ffi.cdata*): integer
---@field stbtt_PackEnd fun(spc:stbtt.ffi.PackContext)
---@field stbtt_PackFontRange fun(spc:stbtt.ffi.PackContext, fontdata:ffi.cdata*, font_index:integer, font_size:number, first_unicode_codepoint_in_range:integer, num_chars_in_range:integer, chardata_for_range:stbtt.ffi.PackedChar): integer
---@field stbtt_PackFontRanges fun(spc:stbtt.ffi.PackContext, fontdata:ffi.cdata*, font_index:integer, ranges:stbtt.ffi.PackRange, num_ranges:integer): integer
---@field stbtt_PackSetOversampling fun(spc:stbtt.ffi.PackContext, h_oversample:integer, v_oversample:integer)
---@field stbtt_PackSetSkipMissingCodepoints fun(spc:stbtt.ffi.PackContext, skip:integer)
---@field stbtt_GetPackedQuad fun(chardata:stbtt.ffi.PackedChar, pw:integer, ph:integer, char_index:integer, xpos:ffi.cdata*, ypos:ffi.cdata*, q:stbtt.ffi.AlignedQuad, align_to_integer:integer)
---@field stbtt_PackFontRangesGatherRects fun(spc:stbtt.ffi.PackContext, info:stbtt.ffi.FontInfo, ranges:stbtt.ffi.PackRange, num_ranges:integer, rects:stbtt.ffi.Rect): integer
---@field stbtt_PackFontRangesPackRects fun(spc:stbtt.ffi.PackContext, rects:stbtt.ffi.Rect, num_rects:integer)
---@field stbtt_PackFontRangesRenderIntoRects fun(spc:stbtt.ffi.PackContext, info:stbtt.ffi.FontInfo, ranges:stbtt.ffi.PackRange, num_ranges:integer, rects:stbtt.ffi.Rect): integer
---@field stbtt_GetNumberOfFonts fun(data:ffi.cdata*): integer
---@field stbtt_GetFontOffsetForIndex fun(data:ffi.cdata*, index:integer): integer
---@field stbtt_InitFont fun(info:stbtt.ffi.FontInfo, data:ffi.cdata*, offset:integer): integer
---@field stbtt_FindGlyphIndex fun(info:stbtt.ffi.FontInfo, unicode_codepoint:integer): integer
---@field stbtt_ScaleForPixelHeight fun(info:stbtt.ffi.FontInfo, pixels:number): number
---@field stbtt_ScaleForMappingEmToPixels fun(info:stbtt.ffi.FontInfo, pixels:number): number
---@field stbtt_GetFontVMetrics fun(info:stbtt.ffi.FontInfo, ascent:ffi.cdata*, descent:ffi.cdata*, lineGap:ffi.cdata*)
---@field stbtt_GetFontVMetricsOS2 fun(info:stbtt.ffi.FontInfo, typoAscent:ffi.cdata*, typoDescent:ffi.cdata*, typoLineGap:ffi.cdata*): integer
---@field stbtt_GetFontBoundingBox fun(info:stbtt.ffi.FontInfo, x0:ffi.cdata*, y0:ffi.cdata*, x1:ffi.cdata*, y1:ffi.cdata*)
---@field stbtt_GetCodepointHMetrics fun(info:stbtt.ffi.FontInfo, codepoint:integer, advanceWidth:ffi.cdata*, leftSideBearing:ffi.cdata*)
---@field stbtt_GetCodepointKernAdvance fun(info:stbtt.ffi.FontInfo, ch1:integer, ch2:integer): integer
---@field stbtt_GetGlyphHMetrics fun(info:stbtt.ffi.FontInfo, glyph_index:integer, advanceWidth:ffi.cdata*, leftSideBearing:ffi.cdata*)
---@field stbtt_GetGlyphKernAdvance fun(info:stbtt.ffi.FontInfo, glyph1:integer, glyph2:integer): integer
---@field stbtt_GetCodepointBox fun(info:stbtt.ffi.FontInfo, codepoint:integer, x0:ffi.cdata*, y0:ffi.cdata*, x1:ffi.cdata*, y1:ffi.cdata*): integer
---@field stbtt_GetGlyphBox fun(info:stbtt.ffi.FontInfo, glyph_index:integer, x0:ffi.cdata*, y0:ffi.cdata*, x1:ffi.cdata*, y1:ffi.cdata*): integer
---@field stbtt_IsGlyphEmpty fun(info:stbtt.ffi.FontInfo, glyph_index:integer): integer
---@field stbtt_GetKerningTableLength fun(info:stbtt.ffi.FontInfo): integer
---@field stbtt_GetKerningTable fun(info:stbtt.ffi.FontInfo, table:stbtt.ffi.KerningEntry, table_length:integer): integer
---@field stbtt_GetCodepointShape fun(info:stbtt.ffi.FontInfo, unicode_codepoint:integer, vertices:ffi.cdata*): integer
---@field stbtt_GetGlyphShape fun(info:stbtt.ffi.FontInfo, glyph_index:integer, vertices:ffi.cdata*): integer
---@field stbtt_FreeShape fun(info:stbtt.ffi.FontInfo, vertices:stbtt.ffi.Vertex)
---@field stbtt_FindSVGDoc fun(info:stbtt.ffi.FontInfo, gl:integer): ffi.cdata*
---@field stbtt_GetCodepointSVG fun(info:stbtt.ffi.FontInfo, unicode_codepoint:integer, svg:ffi.cdata*): integer
---@field stbtt_GetGlyphSVG fun(info:stbtt.ffi.FontInfo, gl:integer, svg:ffi.cdata*): integer
---@field stbtt_FreeBitmap fun(bitmap:ffi.cdata*, userdata:ffi.cdata*)
---@field stbtt_GetCodepointBitmap fun(info:stbtt.ffi.FontInfo, scale_x:number, scale_y:number, codepoint:integer, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_GetCodepointBitmapSubpixel fun(info:stbtt.ffi.FontInfo, scale_x:number, scale_y:number, shift_x:number, shift_y:number, codepoint:integer, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_MakeCodepointBitmap fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, codepoint:integer)
---@field stbtt_MakeCodepointBitmapSubpixel fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, codepoint:integer)
---@field stbtt_MakeCodepointBitmapSubpixelPrefilter fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, oversample_x:integer, oversample_y:integer, sub_x:ffi.cdata*, sub_y:ffi.cdata*, codepoint:integer)
---@field stbtt_GetCodepointBitmapBox fun(info:stbtt.ffi.FontInfo, codepoint:integer, scale_x:number, scale_y:number, ix0:ffi.cdata*, iy0:ffi.cdata*, ix1:ffi.cdata*, iy1:ffi.cdata*)
---@field stbtt_GetCodepointBitmapBoxSubpixel fun(info:stbtt.ffi.FontInfo, codepoint:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, ix0:ffi.cdata*, iy0:ffi.cdata*, ix1:ffi.cdata*, iy1:ffi.cdata*)
---@field stbtt_GetGlyphBitmap fun(info:stbtt.ffi.FontInfo, scale_x:number, scale_y:number, glyph:integer, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_GetGlyphBitmapSubpixel fun(info:stbtt.ffi.FontInfo, scale_x:number, scale_y:number, shift_x:number, shift_y:number, glyph:integer, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_MakeGlyphBitmap fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, glyph:integer)
---@field stbtt_MakeGlyphBitmapSubpixel fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, glyph:integer)
---@field stbtt_MakeGlyphBitmapSubpixelPrefilter fun(info:stbtt.ffi.FontInfo, output:ffi.cdata*, out_w:integer, out_h:integer, out_stride:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, oversample_x:integer, oversample_y:integer, sub_x:ffi.cdata*, sub_y:ffi.cdata*, glyph:integer)
---@field stbtt_GetGlyphBitmapBox fun(info:stbtt.ffi.FontInfo, glyph:integer, scale_x:number, scale_y:number, ix0:ffi.cdata*, iy0:ffi.cdata*, ix1:ffi.cdata*, iy1:ffi.cdata*)
---@field stbtt_GetGlyphBitmapBoxSubpixel fun(info:stbtt.ffi.FontInfo, glyph:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, ix0:ffi.cdata*, iy0:ffi.cdata*, ix1:ffi.cdata*, iy1:ffi.cdata*)
---@field stbtt_Rasterize fun(result:stbtt.ffi.Bitmap, flatness_in_pixels:number, vertices:stbtt.ffi.Vertex, num_verts:integer, scale_x:number, scale_y:number, shift_x:number, shift_y:number, x_off:integer, y_off:integer, invert:integer, userdata:ffi.cdata*)
---@field stbtt_FreeSDF fun(bitmap:ffi.cdata*, userdata:ffi.cdata*)
---@field stbtt_GetGlyphSDF fun(info:stbtt.ffi.FontInfo, scale:number, glyph:integer, padding:integer, onedge_value:integer, pixel_dist_scale:number, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_GetCodepointSDF fun(info:stbtt.ffi.FontInfo, scale:number, codepoint:integer, padding:integer, onedge_value:integer, pixel_dist_scale:number, width:ffi.cdata*, height:ffi.cdata*, xoff:ffi.cdata*, yoff:ffi.cdata*): ffi.cdata*
---@field stbtt_FindMatchingFont fun(fontdata:ffi.cdata*, name:ffi.cdata*, flags:integer): integer
---@field stbtt_CompareUTF8toUTF16_bigendian fun(s1:ffi.cdata*, len1:integer, s2:ffi.cdata*, len2:integer): integer
---@field stbtt_GetFontNameString fun(font:stbtt.ffi.FontInfo, length:ffi.cdata*, platformID:integer, encodingID:integer, languageID:integer, nameID:integer): ffi.cdata*
local C            = ffi.load(here .. libName)

local stbtt        = {}

---@class stbtt.ffi.FontInfo: ffi.cdata*
---@class stbtt.ffi.BakedChar: ffi.cdata*
---@class stbtt.ffi.AlignedQuad: ffi.cdata*
---@class stbtt.ffi.PackedChar: ffi.cdata*
---@class stbtt.ffi.PackContext: ffi.cdata*
---@class stbtt.ffi.Vertex: ffi.cdata*
---@class stbtt.ffi.KerningEntry: ffi.cdata*
---@class stbtt.ffi.PackRange: ffi.cdata*
---@class stbtt.ffi.Bitmap: ffi.cdata*
---@class stbtt.ffi.Rect: ffi.cdata*

---@type fun(): stbtt.ffi.FontInfo
stbtt.FontInfo     = ffi.typeof("stbtt_fontinfo")

---@type fun(n: integer): stbtt.ffi.BakedChar
stbtt.BakedChar    = ffi.typeof("stbtt_bakedchar[?]")

---@type fun(): stbtt.ffi.AlignedQuad
stbtt.AlignedQuad  = ffi.typeof("stbtt_aligned_quad")

---@type fun(n: integer): stbtt.ffi.PackedChar
stbtt.PackedChar   = ffi.typeof("stbtt_packedchar[?]")

---@type fun(): stbtt.ffi.PackContext
stbtt.PackContext  = ffi.typeof("stbtt_pack_context")

---@type fun(n: integer): stbtt.ffi.Vertex
stbtt.Vertex       = ffi.typeof("stbtt_vertex[?]")

---@type fun(n: integer): stbtt.ffi.KerningEntry
stbtt.KerningEntry = ffi.typeof("stbtt_kerningentry[?]")

---@type fun(n: integer): stbtt.ffi.PackRange
stbtt.PackRange    = ffi.typeof("stbtt_pack_range[?]")

---@type fun(n: integer): stbtt.ffi.Rect
stbtt.Rect         = ffi.typeof("struct stbrp_rect[?]")

-- Constants
stbtt.vmove        = 1
stbtt.vline        = 2
stbtt.vcurve       = 3
stbtt.vcubic       = 4

stbtt.platformId   = { Unicode = 0, Mac = 1, ISO = 2, Microsoft = 3 }
stbtt.macStyle     = { Dontcare = 0, Bold = 1, Italic = 2, Underscore = 4, None = 8 }
stbtt.unicodeEid   = { Unicode1_0 = 0, Unicode1_1 = 1, ISO10646 = 2, Unicode2_0BMP = 3, Unicode2_0Full = 4 }
stbtt.msEid        = { Symbol = 0, UnicodeBMP = 1, ShiftJIS = 2, UnicodeFull = 10 }


stbtt.getNumberOfFonts                     = C.stbtt_GetNumberOfFonts
stbtt.getFontOffsetForIndex                = C.stbtt_GetFontOffsetForIndex
stbtt.initFont                             = function(info, data, offset)
	return C.stbtt_InitFont(info, data, offset) ~= 0
end

stbtt.findGlyphIndex                       = C.stbtt_FindGlyphIndex
stbtt.scaleForPixelHeight                  = C.stbtt_ScaleForPixelHeight
stbtt.scaleForMappingEmToPixels            = C.stbtt_ScaleForMappingEmToPixels
stbtt.getFontVMetrics                      = C.stbtt_GetFontVMetrics

---@type fun(info:ffi.cdata*, ta:ffi.cdata*, td:ffi.cdata*, tg:ffi.cdata*): boolean
stbtt.getFontVMetricsOS2                   = function(info, ta, td, tg)
	return C.stbtt_GetFontVMetricsOS2(info, ta, td, tg) ~= 0
end

stbtt.getFontBoundingBox                   = C.stbtt_GetFontBoundingBox
stbtt.getCodepointHMetrics                 = C.stbtt_GetCodepointHMetrics
stbtt.getCodepointKernAdvance              = C.stbtt_GetCodepointKernAdvance
stbtt.getGlyphHMetrics                     = C.stbtt_GetGlyphHMetrics
stbtt.getGlyphKernAdvance                  = C.stbtt_GetGlyphKernAdvance

---@type fun(info:ffi.cdata*, cp:integer, x0:ffi.cdata*, y0:ffi.cdata*, x1:ffi.cdata*, y1:ffi.cdata*): boolean
stbtt.getCodepointBox                      = function(info, cp, x0, y0, x1, y1)
	return C.stbtt_GetCodepointBox(info, cp, x0, y0, x1, y1) ~= 0
end

---@type fun(info:ffi.cdata*, gi:integer, x0:ffi.cdata*, y0:ffi.cdata*, x1:ffi.cdata*, y1:ffi.cdata*): boolean
stbtt.getGlyphBox                          = function(info, gi, x0, y0, x1, y1)
	return C.stbtt_GetGlyphBox(info, gi, x0, y0, x1, y1) ~= 0
end

---@type fun(info:ffi.cdata*, gi:integer): boolean
stbtt.isGlyphEmpty                         = function(info, gi) return C.stbtt_IsGlyphEmpty(info, gi) ~= 0 end

stbtt.getKerningTableLength                = C.stbtt_GetKerningTableLength
stbtt.getKerningTable                      = C.stbtt_GetKerningTable
stbtt.getCodepointShape                    = C.stbtt_GetCodepointShape
stbtt.getGlyphShape                        = C.stbtt_GetGlyphShape
stbtt.freeShape                            = C.stbtt_FreeShape
stbtt.freeBitmap                           = C.stbtt_FreeBitmap
stbtt.getCodepointBitmap                   = C.stbtt_GetCodepointBitmap
stbtt.getCodepointBitmapSubpixel           = C.stbtt_GetCodepointBitmapSubpixel
stbtt.makeCodepointBitmap                  = C.stbtt_MakeCodepointBitmap
stbtt.makeCodepointBitmapSubpixel          = C.stbtt_MakeCodepointBitmapSubpixel
stbtt.makeCodepointBitmapSubpixelPrefilter = C.stbtt_MakeCodepointBitmapSubpixelPrefilter
stbtt.getCodepointBitmapBox                = C.stbtt_GetCodepointBitmapBox
stbtt.getCodepointBitmapBoxSubpixel        = C.stbtt_GetCodepointBitmapBoxSubpixel
stbtt.getGlyphBitmap                       = C.stbtt_GetGlyphBitmap
stbtt.getGlyphBitmapSubpixel               = C.stbtt_GetGlyphBitmapSubpixel
stbtt.makeGlyphBitmap                      = C.stbtt_MakeGlyphBitmap
stbtt.makeGlyphBitmapSubpixel              = C.stbtt_MakeGlyphBitmapSubpixel
stbtt.makeGlyphBitmapSubpixelPrefilter     = C.stbtt_MakeGlyphBitmapSubpixelPrefilter
stbtt.getGlyphBitmapBox                    = C.stbtt_GetGlyphBitmapBox
stbtt.getGlyphBitmapBoxSubpixel            = C.stbtt_GetGlyphBitmapBoxSubpixel
stbtt.rasterize                            = C.stbtt_Rasterize
stbtt.freeSDF                              = C.stbtt_FreeSDF
stbtt.getGlyphSDF                          = C.stbtt_GetGlyphSDF
stbtt.getCodepointSDF                      = C.stbtt_GetCodepointSDF
stbtt.findMatchingFont                     = C.stbtt_FindMatchingFont

---@type fun(s1:ffi.cdata*, l1:integer, s2:ffi.cdata*, l2:integer): boolean
stbtt.compareUTF8toUTF16BigEndian          = function(s1, l1, s2, l2)
	return C.stbtt_CompareUTF8toUTF16_bigendian(s1, l1, s2, l2) ~= 0
end

stbtt.getFontNameString                    = C.stbtt_GetFontNameString
stbtt.bakeFontBitmap                       = C.stbtt_BakeFontBitmap
stbtt.getBakedQuad                         = C.stbtt_GetBakedQuad
stbtt.getScaledFontVMetrics                = C.stbtt_GetScaledFontVMetrics

---@type fun(spc:ffi.cdata*, pixels:ffi.cdata*, width:integer, height:integer, stride_in_bytes:integer, padding:integer, alloc_context:ffi.cdata*): boolean
stbtt.packBegin                            = function(spc, pixels, width, height, stride_in_bytes, padding, alloc_context)
	return C.stbtt_PackBegin(spc, pixels, width, height, stride_in_bytes, padding, alloc_context) ~= 0
end

stbtt.packEnd                              = C.stbtt_PackEnd

---@type fun(spc:ffi.cdata*, fontdata:ffi.cdata*, font_index:integer, font_size:number, first_unicode_codepoint_in_range:integer, num_chars_in_range:integer, chardata_for_range:ffi.cdata*): boolean
stbtt.packFontRange                        = function(spc, fontdata, font_index, font_size,
													  first_unicode_codepoint_in_range, num_chars_in_range,
													  chardata_for_range)
	return C.stbtt_PackFontRange(spc, fontdata, font_index, font_size, first_unicode_codepoint_in_range,
		num_chars_in_range, chardata_for_range) ~= 0
end

---@type fun(spc:ffi.cdata*, fontdata:ffi.cdata*, font_index:integer, font_size:number, ranges:ffi.cdata*, num_ranges:integer): boolean
stbtt.packFontRanges                       = function(spc, fontdata, font_index, font_size, ranges, num_ranges)
	return C.stbtt_PackFontRanges(spc, fontdata, font_index, font_size, ranges, num_ranges) ~= 0
end

stbtt.packSetOversampling                  = C.stbtt_PackSetOversampling
stbtt.packSetSkipMissingCodepoints         = C.stbtt_PackSetSkipMissingCodepoints
stbtt.getPackedQuad                        = C.stbtt_GetPackedQuad
stbtt.packFontRangesGatherRects            = C.stbtt_PackFontRangesGatherRects
stbtt.packFontRangesPackRects              = C.stbtt_PackFontRangesPackRects

---@type fun(spc:ffi.cdata*, info:ffi.cdata*, ranges:ffi.cdata*, num_ranges:integer, rects:ffi.cdata*): boolean
stbtt.packFontRangesRenderIntoRects        = function(spc, info, ranges, num_ranges, rects)
	return C.stbtt_PackFontRangesRenderIntoRects(spc, info, ranges, num_ranges, rects) ~= 0
end

return stbtt
