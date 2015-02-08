# cache_sim_lua
Cache Simulator in Lua

Will support CMP snooping

Usage: the core simulator should send memory load/store instructions
to the cache simulator, which will return the delay. Then the
simulator shall deal with the delay, e.g. to check if the delay could
be hidden by OOO, or will cause performance penalty.
