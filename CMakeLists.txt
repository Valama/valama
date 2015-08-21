cmake_minimum_required(VERSION "2.8.4")

set(TARGET "cmaketest" CACHE STRING "Target")
if ("${TARGET}" STREQUAL "cmaketest")
  include("CMake_cmaketest.txt")
endif ("${TARGET}" STREQUAL "cmaketest")
