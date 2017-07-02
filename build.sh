#!/bin/bash
cd $(dirname "$0")
git submodule sync --recursive
git submodule update --init --recursive
lazbuild Software/components/synapse/laz_synapse.lpk
lazbuild Software/components/general/general_nogui.lpk
lazbuild Software/src/usbavrlabtool.lpi
