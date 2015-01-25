#!/usr/bin/env lua

-- Usage: 

-- require "pepperfish"
function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

local cache = require "cache"

local L1 = cache:new{
   name = "L1",			-- L1 of 8KB
   word_size = 4,		-- word size
   blk_size = 64,		-- block size
   n_blks = 128,		-- n_blks
   assoc = 4,			-- assoc
   hit_time = 1,		-- hit_time
   write_time = 4,		-- write_time
   write_back = true,		-- write_back
   next_level = nil}		-- next_level


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
   -- if rw == 'W' then
   L1:write(addr)
   -- end
end
