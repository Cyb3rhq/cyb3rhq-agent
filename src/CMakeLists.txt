cmake_minimum_required(VERSION 3.22)

set(CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake")

project(cyb3rhq-agent)

include(cmake/CommonSettings.cmake)
set_common_settings()

add_subdirectory(agent)

add_executable(cyb3rhq-agent agent/src/main.cpp)
target_link_libraries(cyb3rhq-agent Agent)

if(BUILD_TESTS)
    enable_testing()
endif()
