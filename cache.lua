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

function _M:read (addr)

end

-- return: hit or not
function _M:write (addr, val)
   -- this is the MEM, will always hit
   if not self.next_level then
      return true
   end

   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   logd(string.format("%x %x %x", tag, index, offset))

   local sets = self._sets
   local tags = self._tags

   local set = sets[index]
   if set then
      for i, blk in ipairs(set) do
	 if blk.tag == tag then	-- a hit
	    blk[offset] = val
	 end
      end
   end
   
end

