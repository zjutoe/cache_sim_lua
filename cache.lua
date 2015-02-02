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
   print(...)
end

function bit_mask(msb, lsb)	
   if msb <= lsb then return end

   local t = 0xffffffff
   if msb < 31 then
      t = bit.lshift(0xffffffff, msb + 1) 
      t = bit.bnot(t)			  
   end

   local s = bit.lshift(0xffffffff, lsb) 
   return bit.band(t, s)	
end

name = "MEM"			-- example cache of 8KB
word_size = 4			-- word size in bytes
blk_size = 64			-- block size in bytes, 2^6
n_blks = 128			-- n_blks, 2^7
assoc = 4			-- assoc
hit_time = 1			-- hit_time
write_time = 4			-- write_time
-- write_back = true		-- write_back
next_level = nil

read_miss = 0
read_hit = 0
write_miss = 0
write_hit = 0
write_back_cnt = 0

read_hit_delay = 1
write_hit_delay = 1
read_miss_delay = 5
write_miss_delay = 5

_sets = {}
_tags = {}
_clk = 0

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

   obj.n_sets = obj.n_blks / obj.assoc

   offset_lsb = math.log (obj.word_size) / math.log (2)
   offset_msb = obj.offset_lsb + math.log (obj.blk_size) / math.log (2) - 1
   logd('offset:', offset_msb, offset_lsb)

   obj.offset_mask = bit_mask(offset_msb, offset_lsb)

   index_lsb = offset_msb + 1
   index_msb = index_lsb + math.log (obj.n_sets) / math.log (2) - 1
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
   local block
   local hit = false
   local write_back_addr = nil

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
	    
	    block = set[vict]
	    write_back_addr = bit.bor(block.tag, index)
	    self.write_back_cnt = self.write_back_cnt + 1
	 end			-- if i < self.assoc

	 block.tag = tag
      end      			-- if not hit

   else				-- this set is never accessed before
      sets[index] = {}		-- new set
      sets[index][0] = {}	-- new block
      block = sets[index][0]
      block.tag = tag
   end				-- if set

   block.atime = self.clk
   return block, hit, write_back_addr
end

function _M:read(addr)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("R: %x %x %x", tag, index, offset))

   local delay = 0
   local blk, hit, write_back_addr = self:search_block(tag, index)
   logd("R", hit and 'hit' or 'miss')

   if hit then
      self.read_hit = self.read_hit + 1
      delay = delay + self.read_hit_delay
      
   else				-- miss
      self.read_miss = self.read_miss + 1
      delay = delay + self.read_miss_delay

      if self.next_level then
	 if write_back_addr then
	    delay = delay + self.next_level:write(write_back_addr)
	 end
	 delay = delay + self.next_level:read(addr)
	 delay = delay + self.read_miss_delay -- FIXME: what is self.miss_delay?
      end
   end				-- if hit

   return delay
end

function _M:write(addr, val)
   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("W: %x %x %x", tag, index, offset))

   local blk, hit, write_back_addr = self:search_block(tag, index)
   logd("W", hit and 'hit' or 'miss')

   local delay = 0
   if hit then
      self.write_hit = self.write_hit + 1
      delay = delay + self.write_hit_delay

   else				-- miss
      self.write_miss = self.write_miss + 1
      delay = delay + self.write_miss_delay

      if self.next_level then
	 if write_back_addr then
	    delay = delay + self.next_level:write(write_back_addr)
	 end
	 delay = delay + self.next_level:read(addr)
	 delay = delay + self.write_miss_delay
      end
   end				-- if hit

   return delay
end

