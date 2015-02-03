#!/usr/bin/env lua

-- Usage: 

-- require "pepperfish"
function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local cache = require "cache"

local L3 = cache:new{
   name = "L3",			-- L3 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 128,		-- n_blks, 2^7
   assoc = 4,			-- assoc
   hit_time = 4,		-- hit_time
   write_time = 8,		-- write_time
   write_back = true,		-- write_back
   next_level = nil}		-- next_level

local L2 = cache:new{
   name = "L2",			-- L3 of 8KB
   word_size = 4,		-- word size in bytes
   blk_size = 64,		-- block size in bytes, 2^6
   n_blks = 64,			-- n_blks, 2^6
   assoc = 4,			-- assoc
   hit_time = 1,		-- hit_time
   write_time = 2,		-- write_time
   write_back = true,		-- write_back
   next_level = L3}		-- next_level


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
   local delay = 0
   -- print(rw, addr, cid)
   if rw == 'W' then
      delay = L2:write(tonumber(addr, 16))
   elseif rw == 'R' then
      delay = L2:read(tonumber(addr, 16))
   end
   print('delay', delay)
end

function summarize(c) 
   print(c.name)
   print("read hit/miss:", c.read_hit, c.read_miss)
   print("write hit/miss:", c.write_hit, c.write_miss)
end

summarize(L2)
summarize(L3)
