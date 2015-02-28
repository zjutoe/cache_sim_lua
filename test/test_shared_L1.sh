#!/bin/bash

if [ ! -h cache.lua ]; then
    ln -s ../cache.lua
fi

luajit test_shared_L1.lua date.mref.log

