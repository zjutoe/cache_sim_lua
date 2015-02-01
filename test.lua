#!/usr/bin/env lua

-- Usage: 

-- require "pepperfish"
function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local cache = require "cache"

local MEM = cache:new{
   name = "L3",			-- L3 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 128,		-- n_blks, 2^7
   assoc = 4,			-- assoc
   hit_time = 1,		-- hit_time
   write_time = 4,		-- write_time
   write_back = true,		-- write_back
   next_level = nil}		-- next_level

-- print(L1.name)
-- print(   L1.word_size )
-- print(   L1.blk_size )
-- print(   L1.n_blks )
-- print(   L1.assoc )
-- print(   L1.hit_time )
-- print(   L1.write_time )
-- print(   L1.write_back )
-- print(   L1.next_level )

-- print(L1.n_sets)
-- print(L1.blk_offset_lsb)
-- print(L1.blk_offset_msb)
-- print(L1.addr_index_lsb)
-- print(L1.addr_index_msb)
-- print(L1.addr_tag_lsb)
-- print(L1.addr_tag_msb)

local BUFSIZE = 2^8		-- 32K
local f = io.input(arg[1])	-- open input file
-- local cc, lc, wc = 0, 0, 0	-- char, line, and word counts
-- while true do
--    -- print(__LINE__())
--    local lines, rest = f:read(BUFSIZE, "*line")
--    if not lines then break end
--    if rest then lines = lines .. rest .. "\n" end

--    assert(loadstring(lines))()
-- end

for line in f:lines() do
   local rw, addr, cid = string.match(line, "(%a) 0x(%x+) (%d)")
   -- print(rw, addr, cid)
   if rw == 'W' then
      MEM:write(tonumber(addr, 16))
   elseif rw == 'R' then
      MEM:read(tonumber(addr, 16))
   end
end
