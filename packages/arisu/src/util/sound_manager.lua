local ffi = require("ffi")
local treble = require("treble")

--- Every sound the application can make. The file is embedded in the build like
--- any other asset, so a sound is never looked up on disk at runtime.
---@class SoundManager.Sound
---@field module string # The embedded asset module to require
---@field volume number # How loud it is against the application volume

---@type table<string, SoundManager.Sound>
local SOUNDS = {
	pop = { module = "arisu.assets.sounds.pop", volume = 0.7 },
	twang = { module = "arisu.assets.sounds.twang", volume = 0.5 }
}

-- Each voice holds its own device stream, so this is what keeps a burst of
-- clicking from opening a stream per event. A sound beyond the cap is dropped
-- rather than stacked on top of the ones already playing.
local MAX_VOICES = 8

---@class SoundManager.SoundData
---@field bytes string # Held because the decoder reads straight out of it
---@field pointer ffi.cdata*
---@field size number
---@field volume number

---@class SoundManager
---@field sounds table<string, SoundManager.SoundData>
---@field voices treble.Player[]
---@field volume number
---@field isMuted boolean
---@field isAvailable boolean
local SoundManager = {}
SoundManager.__index = SoundManager

--- Decodes (lazily: only the header is read) every embedded sound once, so
--- playing one costs nothing but a copy into the device.
---@return SoundManager
function SoundManager.new()
	local self = setmetatable({
		sounds = {},
		voices = {},
		volume = 1,
		isMuted = true,
		isAvailable = true
	}, SoundManager)

	for name, sound in pairs(SOUNDS) do
		local bytes = require(sound.module) --[[@as string]]

		self.sounds[name] = {
			bytes = bytes,
			pointer = ffi.cast("const char*", bytes),
			size = #bytes,
			volume = sound.volume
		}
	end

	return self
end

--- Gives up on the device after the first failure. A machine with no sound card,
--- or with one another program holds open, must not take the application down
--- with it, nor print the same error on every click.
---@param err string
function SoundManager:disable(err)
	if not self.isAvailable then
		return
	end

	self.isAvailable = false
	print("Sound is unavailable: " .. err)
end

--- Starts a sound without waiting for it to finish. Two effects overlap instead
--- of cutting each other off, and nothing at all happens while muted.
---@param name string # A key of SOUNDS
---@param volume number? # Multiplier on top of the sound's own volume
---@return treble.Player? player
function SoundManager:play(name, volume)
	if self.isMuted or not self.isAvailable then
		return nil
	end

	local sound = self.sounds[name]
	if sound == nil or #self.voices >= MAX_VOICES then
		return nil
	end

	local source = treble.Audio.fromMemory(sound.pointer, sound.size)
	if source == nil then
		return nil
	end

	local player = treble.Player.new()
	player.onError = function(err)
		self:disable(err)
	end

	player:enqueue(source)
	player:setVolume(sound.volume * self.volume * (volume or 1))
	player:play()

	self.voices[#self.voices + 1] = player

	return player
end

--- Feeds the device and lets go of the sounds that have finished. Worth calling
--- once a frame: a sound plays without it, but its stream stays open.
function SoundManager:update()
	for i = #self.voices, 1, -1 do
		local player = self.voices[i]

		player:update()

		if player:isFinished() then
			player:close()
			table.remove(self.voices, i)
		end
	end
end

--- Cuts every sound that is still playing.
function SoundManager:stop()
	for _, player in ipairs(self.voices) do
		player:stop()
		player:close()
	end

	self.voices = {}
end

---@param isMuted boolean
---@return SoundManager
function SoundManager:setMuted(isMuted)
	self.isMuted = isMuted

	if isMuted then
		self:stop()
	end

	return self
end

---@return boolean isMuted
function SoundManager:toggleMuted()
	self:setMuted(not self.isMuted)

	return self.isMuted
end

---@param volume number # 0 to 1
---@return SoundManager
function SoundManager:setVolume(volume)
	self.volume = math.max(0, math.min(1, volume))

	return self
end

return SoundManager
