include(${CMAKE_SOURCE_DIR}/cmake/project.cmake)

cmake_minimum_required(VERSION 2.8)
project("${project_name}" C)

set(CMAKE_INSTALL_PREFIX "/usr")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Vala "0.16" REQUIRED)

set(srcfiles "${PROJECT_SOURCE_DIR}/src/*.vala")
include(ValaPkgs)
vala_pkgs(VALA_C
  PACKAGES
    ${required_pkgs}
  OPTIONAL
    ${optional_pkgs}
  SRCFILES
    ${srcfiles}
    ${PROJECT_SOURCE_DIR}/config.vala
  OPTIONS
    --thread
    ${valac_cond}
)
if(NOT PkgConfig_FOUND)
  find_package(PkgConfig)
endif()
pkg_check_modules(GTHREAD REQUIRED gthread-2.0)
add_definitions(${GTHREAD_CFLAGS})
link_libraries(${GTHREAD_LIBRARIES})

add_executable("${project_name}" ${VALA_C})
