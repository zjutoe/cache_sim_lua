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
function _M:new (obj)

   obj = obj or {}
   setmetatable(obj, self)
   self.__index = self
   
   obj.n_sets = obj.n_blks / obj.assoc
   -- least significant bit of block offset, i.e. 2, as addr[1:0] are left for 32 bits word
   obj.blk_offset_lsb = math.log (obj.word_size) / math.log (2)
   -- most significant bit of block offset
   obj.blk_offset_msb = obj.blk_offset_lsb + math.log (obj.blk_size) / math.log (2)
   -- least and most significant bit of index
   obj.addr_index_lsb = obj.blk_offset_msb + 1
   obj.addr_index_msb = obj.addr_index_lsb + math.log (obj.n_sets) / math.log (2)
   -- least and most significant bit of tag
   obj.addr_tag_lsb = obj.addr_index_msb + 1
   obj.addr_tag_msb = obj.word_size * 8 - 1   

   return obj
end

function bit_segment(v, msb, lsb)
   return bit.rshift(bit.lshift(v, 32 - msb), msb + lsb)
end

function _M:parse_address(addr)
   local tag, index, offset

   tag = bit_segment(addr, self.addr_tag_msb, self.addr_tag_lsb)
   index = bit_segment(addr, self.addr_index_msb, self.addr_index_lsb)
   offset = bit_segment(addr, self.blk_offset_msb, self.blk_offset_lsb)

   return tag, index, offset
end

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

   local tag, index, offset = self:parse_address(addr)
   print (string.format("%x %x %x", tag, index, offset))

end

