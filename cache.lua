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

-- return: hit or not
function _M:read_write(is_write, addr, val)
   -- this is the MEM, will always hit
   if not self.next_level then
      return true
   end

   local hit = false

   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%x %x %x", tag, index, offset))

   local sets = self._sets
   local tags = self._tags

   local set = sets[index]
   if set then
      local i = 0
      for _, blk in pairs(set) do
	 i = i + 1
	 if blk.tag == tag then	-- a hit
	    hit = true
	    if is_write then
	       self.write_hit = self.write_hit + 1 
	       _M:write_block(blk, offset, tag, val, false)
	    else
	       self.read_hit = self.read_hit + 1 
	       _M:read_block(blk, offset, tag, val, false)
	    end
	    break
	 end
      end
      if not hit then		-- a miss
	 if is_write then
	    self.write_miss = self.write_miss + 1
	 else
	    self.read_hit = self.read_hit + 1 
	 end

	 if i < self.assoc then -- set not full yet
	    for j = 0, self.assoc - 1 do
	       if not set[j] then 
		  set[j] = {}
		  if is_write then
		     _M:write_block(set[j], offset, tag, val, false)
		  else
		     _M:read_block(set[j], offset, tag, val, false)
		  end
		  break
	       end
	    end
	 else			-- set is full, need to find a victim
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
	    -- NOTE: should evict the victim if it contains dirty data
	    if is_write then
	       _M:write_block(set[vict], offset, tag, val, set[vict].dirty)
	    else
	       _M:read_block(set[vict], offset, tag, val, set[vict].dirty)
	    end
	 end
      end
   else				-- this set is never accessed before
      sets[index] = {}		-- new set
      sets[index][0] = {}	-- new block
      if is_write then
	 self.write_miss = self.write_miss + 1
	 _M:write_block(sets[index][0], offset, tag, val, false)
      else
	 self.read_miss = self.read_miss + 1
	 _M:read_block(sets[index][0], offset, tag, val, false)
      end
   end   

   return hit
end
