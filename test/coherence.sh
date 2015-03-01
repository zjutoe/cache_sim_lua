#!/bin/bash

if [ ! -h cache.lua ]; then
    ln -s ../cache.lua
fi

#luajit test_coherence.lua test_coherence.trace
luajit test_coherence.lua date.mref.log

