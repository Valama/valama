#!/bin/sh
set -ex

autoreconf -f -i -Wall,error
./configure
