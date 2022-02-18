
local NULLTABLE = {}
local __index = function(self, key)
	return self._default[key] or self._classtable[key]
end
local __newindex = function(self, key, value)
	rawset(self._default, key, value)
end
local __call = function(self)
	return self._default(self)
end
local __pairs = function(self)
	return function(self, key)
		local value
		repeat
			key, value = next(self, key)
		until key == nil or tostring(key):sub(1,1) ~= "_"
		return key, value
	end, self, nil
end

local __indexMagic = function(self, key)
	return self._default[key]
end

local __pairsMagic = function(self)
	defaultRemaining = true
	return function(self, key)
		local value

		if defaultRemaining then
			repeat
				key, value = next(self._default, key)
			until key == nil or tostring(key):sub(1,1) ~= "_"
		end

		if key == nil then
			defaultRemaining = false
		end

		if not defaultRemaining then
			repeat
				key, value = next(self, key)
			until key == nil or tostring(key):sub(1,1) ~= "_"
		end

		return key, value
	end, self, nil
end


IndexedEntryMetatableUnlocked = {
	__index = __index,
	__newindex = __newindex,
	__call = __call,
	-- The mod loader's pairs implementation
	-- checks the table itself instead of
	-- the metatable for __pairs metamethod
	-- __pairs = __pairs,
}

IndexedEntryMetatableLocked = {
	__index = __index,
	__call = __call,
	-- __pairs = __pairs,
}

LockedTableEntryMetatable = {
	__index = __indexMagic
}


IndexedList = Class.new()
IndexedEntry = Class.new()
IndexedList._debugName = "IndexedList"
IndexedEntry._debugName = "IndexedEntry"

function IndexedList:new(class)
	Assert.True(IndexedEntry.isSubclassOf(class, IndexedEntry), "Argument #1")
	Assert.Equals('string', type(class._entryType), "No - or invalid '_entryType'")

	self._class = class
	self._children = {}
end

function IndexedList:add(id, base)
	Assert.Equals('string', type(id), "Argument #1")
	Assert.Equals({'nil', 'string', 'table'}, type(base), "Argument #2")
	Assert.Equals('nil', type(self:get(id)), "Entry already exists")

	if type(base) == 'string' then
		base = self:get(base)
	end

	local entry = self._class(id, base)
	self._children[id] = entry
	self.__pairs = __pairs

	return entry
end

function IndexedList:getDebugName()
	return self._debugName
end

function IndexedList:getId()
	return self._id
end

function IndexedList:getIconDef()
	return self._class:getIconDef()
end

function IndexedList:getEntryType()
	return self._class:getEntryType()
end

function IndexedList:getDragType()
	return self._class:getDragType()
end

function IndexedList:get(id)
	return self._children[id]
end

function IndexedList:rem(id)
	self._children[id] = nil
end

function IndexedList:save()
	-- LOGDF("Save cached data for %s", tostring(self:getEntryType()))
	-- overrideable method
	easyEdit.savedata.cache[self:getEntryType()] = copy_table(self._children)
	easyEdit.savedata:save()
end

-- Update lists from savedata,
-- and apply updates to game objects
function IndexedList:update()
	-- overrideable method
	local entryType = self:getEntryType()
	local setFunction = "set"..entryType:gsub("^.", string.upper)
	local cache_savedata = easyEdit.savedata.cache[entryType] or NULLTABLE

	for cache_id, cache_data in pairs(cache_savedata) do
		local livedata = modApi[entryType]:get(cache_id)

		if livedata == nil then
			livedata = modApi[entryType]:add(cache_id)
			livedata:lock()
		end

		if livedata then
			clear_table(livedata)
			clone_table(livedata, cache_data)
		end
	end

	local cache_world = easyEdit.savedata.cache.world or NULLTABLE

	for islandSlot, cache_data in ipairs(cache_world) do
		local cache_islandComposite = modApi.islandComposite:get(cache_data)
		local livedataId = modApi[entryType]:get(cache_islandComposite[entryType])

		modApi.world[setFunction](modApi.world, islandSlot, livedataId)
	end
end


function IndexedEntry:new(id, base)
	Assert.Equals('string', type(id), "Argument #1")
	Assert.Equals({'nil', 'table'}, type(base), "Argument #2")

	local classmetatable = getmetatable(self)
	local classtable = classmetatable.__index

	self._default = classmetatable
	self._default.__pairs = __pairs
	self._classtable = classtable
	self.__pairs = __pairs

	setmetatable(self, IndexedEntryMetatableUnlocked)

	self._id = id
	self:copy(base)
end

function IndexedEntry:extend()
	local o = Class.extend(self)
	o.instanceOf = nil
	return o
end

function IndexedEntry:instanceOf(cls)
	if type(cls) ~= 'table' then
		LOG(type(cls))
	end
	Assert.Equals(type(self), 'table', "Argument #0")
	Assert.Equals(type(cls), 'table', "Argument #1")

	local classtable = self._classtable

	if classtable == nil then
		return false
	end

	return classtable:isSubclassOf(cls)
end

function IndexedEntry:getDebugName()
	return self._debugName
end

function IndexedEntry:getId()
	return self._id
end

function IndexedEntry:getName()
	return self._id
end

function IndexedEntry:isVanilla()
	return self._vanilla == true
end

function IndexedEntry:isMod()
	return self._mod == true
end

function IndexedEntry:isCustom()
	return not self._mod and not self._vanilla
end

function IndexedEntry:getDragType()
	Assert.Error("Drag type not defined")
end

function IndexedEntry:getTooltipDef()
	return self._tooltipDef or self._iconDef
end

function IndexedEntry:getIconDef()
	-- overridable method
	return self._iconDef
end

function IndexedEntry:getEntryType()
	-- overridable method
	return self._entryType
end

function IndexedEntry:lock()
	setmetatable(self, IndexedEntryMetatableLocked)

	for key, entry in pairs(self._default) do
		self[key] = copy_table(entry)
	end
end

function IndexedEntry:delete(save)
	if not self:isCustom() then
		return false
	end

	local id = self:getId()
	local entryType = self:getEntryType()
	modApi[entryType]._children[id] = nil

	if save then
		modApi[entryType]:save()
	end

	return true
end

function IndexedEntry:reset()
	self:copy(self._default)
end

function IndexedEntry:copy(base)
	if type(base) ~= 'table' then return end

	for key, value in pairs(base) do
		if not modApi:stringStartsWith(key, "_") then
			self[key] = copy_table(value)
		end
	end
end
