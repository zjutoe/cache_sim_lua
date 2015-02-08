local bit = require("bit")

function bit_mask(msb, lsb)
   local t = 0xffffffff
   if (msb < 31) then
      t = bit.lshift(0xffffffff, msb+1)
      t = bit.bnot(t)
   end

   local s = bit.lshift(0xffffffff, lsb)
   return bit.band(t, s)
end

print(bit.tohex(bit_mask(7, 2)))
print(bit.tohex(bit_mask(16, 8)))
print(bit.tohex(bit_mask(31, 17)))
