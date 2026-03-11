local ffi = require("ffi")
local hood = require("hood")

local Image = require("arisu-image")

local maxWidth = 1024
local maxHeight = 1024
local maxLayers = 256

---@alias Texture number
---@alias TextureMetadata { width: number, height: number, image?: Image }

---@class TextureManager
---@field device hood.Device
---@field textures TextureMetadata[]
---@field textureCount number
---@field textureUVScaleBuffer hood.Buffer
---@field texture hood.Texture
---@field view hood.TextureView
---@field sampler hood.Sampler
---@field whiteTexture Texture
---@field errorTexture Texture
local TextureManager = {}
TextureManager.__index = TextureManager

---@param device hood.Device
function TextureManager.new(device)
	local texture = device:createTexture({
		extents = { dim = "2d", width = maxWidth, height = maxHeight, count = maxLayers },
		format = "rgba8unorm",
		usages = { "TEXTURE_BINDING", "STORAGE_BINDING", "COPY_DST", "COPY_SRC", "RENDER_ATTACHMENT" },
	})

	local sampler = device:createSampler({
		minFilter = "nearest",
		magFilter = "nearest",
		mipmapFilter = "nearest",
		addressModeU = "clamp-to-edge",
		addressModeV = "clamp-to-edge",
		addressModeW = "clamp-to-edge",
	})

	-- Use vec4 for proper alignment
	local textureUVScaleBuffer = device:createBuffer({
		size = maxLayers * ffi.sizeof("float") * 2,
		usages = { "STORAGE", "COPY_DST" },
	})

	local this = setmetatable({
		textureCount = 0,
		textureUVScaleBuffer = textureUVScaleBuffer,
		texture = texture,
		view = texture:createView({}),
		sampler = sampler,
		device = device,
		textures = {},
	}, TextureManager)

	this.whiteTexture = this:upload(Image.new(1, 1, 4, ffi.new("uint8_t[?]", 3, { 255, 255, 255, 255 }), ""))
	this.errorTexture = this:upload(Image.new(
		2,
		2,
		4,
		ffi.new("uint8_t[?]", 16, {
			255,
			0,
			255,
			255,
			0,
			0,
			0,
			255,
			0,
			0,
			0,
			255,
			255,
			0,
			255,
			255,
		}),
		""
	))

	return this
end

function TextureManager:destroy()
	self.texture:destroy()
	self.textureUVScaleBuffer:destroy()
	self.sampler:destroy()
end

---@param id Texture
---@param width number
---@param height number
function TextureManager:setTextureDimensions(id, width, height)
	local texture = self.textures[id]
	assert(texture, "Texture does not exist")

	texture.width, texture.height = width, height

	-- Using std430, don't need to align to vec4
	local uvScale = ffi.new("float[2]", width / maxWidth, height / maxHeight)
	self.device.queue:writeBuffer(self.textureUVScaleBuffer, 8, uvScale, id * 8)
end

---@param width number
---@param height number
---@return Texture
function TextureManager:allocate(width, height)
	local layer = self.textureCount
	if layer >= maxLayers then
		error("Maximum number of texture layers reached")
	end

	self.textures[layer] = { width = width, height = height }
	self:setTextureDimensions(layer, width, height)
	self.textureCount = self.textureCount + 1

	return layer
end

---@param image Image
function TextureManager:update(texture, image)
	assert(self.textures[texture], "Texture does not exist")

	self:setTextureDimensions(texture, image.width, image.height)
	self.device.queue:writeTexture(self.texture, { layer = texture, width = image.width, height = image.height },
		image.pixels)
end

---@param image Image
function TextureManager:upload(image)
	local texture = self:allocate(image.width, image.height)
	self:update(texture, image)
	return texture
end

---@param binding number The binding index for the texture array
---@param samplerBinding number The binding index for the sampler
---@param dimsBinding number The binding index for the dimensions buffer
---@return hood.BindGroupLayout
function TextureManager:createBindGroupLayout(binding, samplerBinding, dimsBinding)
	return self.device:createBindGroupLayout({
		{
			type = "texture",
			binding = binding,
			visibility = { "FRAGMENT" },
		},
		{
			type = "sampler",
			binding = samplerBinding,
			visibility = { "FRAGMENT" },
		},
		{
			type = "buffer",
			binding = dimsBinding,
			visibility = { "FRAGMENT" },
		},
	})
end

---Create a bind group for this texture manager
---@param layout hood.BindGroupLayout The bind group layout to use for this bind group
---@param binding number The binding index for the texture array
---@param samplerBinding number The binding index for the sampler
---@param dimsBinding number The binding index for the dimensions buffer
---@return hood.BindGroup
function TextureManager:createBindGroup(layout, binding, samplerBinding, dimsBinding)
	return self.device:createBindGroup({
		layout = layout,
		entries = {
			{
				type = "texture",
				binding = binding,
				texture = self.view,
				visibility = { "FRAGMENT" },
			},
			{
				type = "sampler",
				binding = samplerBinding,
				sampler = self.sampler,
				visibility = { "FRAGMENT" },
			},
			{
				type = "buffer",
				binding = dimsBinding,
				buffer = self.textureUVScaleBuffer,
				visibility = { "FRAGMENT" },
			},
		},
	})
end

return TextureManager
