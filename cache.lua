local pairs = pairs
local math = math
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local print = print
local string = string
local bit = require("bit")

module (...)

function logd(...)
   -- print(...)
end

function bit_mask(msb, lsb)	
   if msb <= lsb then return end

   local t = 0xffffffff
   if msb < 32 then
      t = bit.lshift(0xffffffff, msb + 1) 
      t = bit.bnot(t)			  
   end

   local s = bit.lshift(0xffffffff, lsb) 
   return bit.band(t, s)	
end


-- name, 
-- word_size, 
-- blk_size, 
-- n_blks, 
-- assoc, 
-- hit_time, 
-- write_time, 
-- write_back, 
-- next_level
function _M:new (obj)

   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self

   obj._sets = {}
   obj._tags = {}
   obj._clk = 0

   obj.n_sets = obj.n_blks / obj.assoc

   offset_lsb = math.log (obj.word_size) / math.log (2)
   offset_msb = obj.offset_lsb + math.log (obj.n_sets) / math.log (2)
   logd('offset:', offset_msb, offset_lsb)

   obj.offset_mask = bit_mask(offset_msb, offset_lsb)

   index_lsb = offset_msb + 1
   index_msb = index_lsb + math.log (obj.n_sets) / math.log (2)
   logd('index:', index_msb, index_lsb)
   obj.index_mask = bit_mask(index_msb, index_lsb)

   tag_lsb = index_msb + 1
   tag_msb = obj.word_size * 8 - 1   
   logd('tag:', tag_msb, tag_lsb)
   obj.tag_mask = bit_mask(tag_msb, tag_lsb)

   logd(string.format('tag:%x index:%x offset:%x', obj.tag_mask, obj.index_mask, obj.offset_mask))

   return obj
end

function _M:tag(addr)
   return bit.band(addr, self.tag_mask)
end

function _M:index(addr)
   return bit.band(addr, self.index_mask)
end

function _M:offset(addr)
   return bit.band(addr, self.offset_mask)
end

function _M:write_block(blk, offset, tag, val, need_wb)
   blk.tag = tag
   blk.atime = self.clk
   -- TODO to read this block from next level of cache; and before
   -- that, if need_wb is set, should write back dirty data
   blk.dirty = true
   blk[offset] = val
end

function _M:read_block(blk, offset, tag, val, need_wb)
   -- if need_wb is set, should write back dirty data
   blk.atime = self.clk
end

function _M:search_block(tag, index)
   local hit = false
   local block
   local write_back = false

   local sets = self._sets

   local set = sets[index]
   if set then
      local i = 0
      for _, blk in pairs(set) do
	 i = i + 1
	 if blk.tag == tag then	-- a hit
	    hit = true
	    block = blk
	    break
	 end
      end

      if not hit then		-- a miss
	 if i < self.assoc then -- set not full yet
	    for j = 0, self.assoc - 1 do
	       if not set[j] then 
		  set[j] = {}
		  block = set[j]
		  break
	       end
	    end
	    
	 else			-- if i < self.assoc
	    -- set is full, need to find a victim
	    local access_time = self.clk
	    local vict = 0
	    -- to find the vict with smallest access time, i.e. least
	    -- recently used
	    for j = 0, self.assoc - 1 do
	       if access_time > set[j].atime then
		  access_time = set[j].atime 
		  vict = j
	       end
	    end

	    -- to evict
	    self:write_back(set[vict])

	    block = set[vict]
	    write_back = true
	 end			-- if i < self.assoc
      end      			-- if not hit

   else				-- if set 
      -- this set is never accessed before
      sets[index] = {}		-- new set
      sets[index][0] = {}	-- new block
      block = sets[index][0]
   end				-- if set

   block.atime = self.clk
   return block, hit, write_back
end

function _M:read(addr)

   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%x %x %x", tag, index, offset))

   local blk, hit, write_back = _M:search_block(tag, index)
   local val, delay
   if hit then
      self.read_hit = self.read_hit + 1
      val, delay = blk[offset], self.read_hit_delay
      
   else
      -- miss
      self.read_miss = self.read_miss + 1
      local next_level = self.next_level
      local _val, _blk, _delay = next_level:read(addr)
      val = _val
      -- FIXME: load the block into the current cache. Is this the
      -- corrent way?
      for k, v in pairs(_blk) do
	 blk[k] = v
      end
      delay = _delay + self.read_miss_delay -- FIXME: what is self.miss_delay?
   end

   return val, blk, delay
end

function _M:write(addr, val)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%x %x %x", tag, index, offset))

   local blk, hit, write_back = _M:search_block(tag, index)
   local delay
   if hit then
      self.write_hit = self.write_hit + 1
      blk[offset] = val
      delay = self.write_hit_delay
   else				-- if hit
      -- miss
      self.write_miss = self.write_miss + 1
      local _val, _blk, _delay = self.next_level:read(addr)
      -- FIXME: load the block into the current cache. Is this the
      -- corrent way?
      for k, v in pairs(_blk) do
	 blk[k] = v
      end
      blk[offset] = val
      delay = self.write_miss_delay + _delay
   end

   return blk, delay
end

