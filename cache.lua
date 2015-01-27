local pairs = pairs
local math = math
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local print = print
local string = string
local bit = require("bit")

module (...)

-- name, 
-- word_size, 
-- blk_size, 
-- n_blks, 
-- assoc, 
-- hit_time, 
-- write_time, 
-- write_back, 
-- next_level

function bit_segment(v, msb, lsb)	     -- v, 3, 2
   local t = bit.lshift(0xffffffff, msb + 1) -- 0x11110000
   t = bit.bnot(t)			     -- 0x00001111
   local s = bit.lshift(0xffffffff, lsb)     -- 0x11111100
   return bit.band(v, bit.band(t, s))	     -- v & 0x00001100
end

function _M:new (obj)

   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self

   local ffff = 0xffffffff;

   obj.n_sets = obj.n_blks / obj.assoc

   offset_lsb = math.log (obj.word_size) / math.log (2)
   offset_msb = obj.offset_lsb + math.log (obj.n_sets) / math.log (2)
   print('offset:', offset_msb, offset_lsb)
   obj.offset_mask = bit.lshift(1, offset_msb + 1)
   obj.offset_mask = bit.bnot(obj.offset_mask)

   obj.offset_mask = bit.rshift(bit.lshift(ffff, 31-offset_msb), 
				31 - offset_msb + offset_lsb)

   -- least and most significant bit of index
   addr_index_lsb = blk_offset_msb + 1
   addr_index_msb = addr_index_lsb + math.log (obj.n_sets) / math.log (2)
   print('index:', addr_index_msb, addr_index_lsb)
   obj.index_mask = bit.rshift(bit.lshift(ffff, 31-addr_index_msb), 
			       31 - addr_index_msb + addr_index_lsb)

   -- least and most significant bit of tag
   addr_tag_lsb = addr_index_msb + 1
   addr_tag_msb = obj.word_size * 8 - 1   
   print('tag:', addr_tag_msb, addr_tag_lsb)
   obj.tag_mask = bit.rshift(bit.lshift(ffff, 31-addr_tag_msb), 
			     31 - addr_tag_msb + addr_tag_lsb)

   print(string.format('tag:%x index:%x offset:%x', obj.tag_mask, obj.index_mask, obj.offset_mask))

   return obj
end

function bit_segment(v, msb, lsb)
   return bit.rshift(bit.lshift(v, 32 - msb), msb + lsb)
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

-- function _M:parse_address(addr)
--    local tag, index, offset

--    tag = bit_segment(addr, self.addr_tag_msb, self.addr_tag_lsb)
--    index = bit_segment(addr, self.addr_index_msb, self.addr_index_lsb)
--    offset = bit_segment(addr, self.blk_offset_msb, self.blk_offset_lsb)

--    return tag, index, offset
-- end

function _M:read (addr)

end

-- return: hit or not
function _M:write (addr)
   -- this is the MEM, will always hit
   if not self.next_level then
      return true
   end

   --local address = tonumber(addr, 16)
   print(string.format('addr:%x', addr))

   local tag, index, offset = self:tag(addr), self:index(addr), self:offset(addr)
   print (string.format("%x %x %x", tag, index, offset))

end

