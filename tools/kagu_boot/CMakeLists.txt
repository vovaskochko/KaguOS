# kagu_boot - KaguOS emulator

add_executable(kagu_boot
    src/main_boot.cpp
    src/cpu.cpp
    src/ram.cpp
    src/interrupt_handler.cpp
    src/disk.cpp
    src/display.cpp
    src/input.cpp
    src/debug_server.cpp
)

target_include_directories(kagu_boot PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(kagu_boot PRIVATE
    kagu::libkagu
)

if (WIN32)
    target_link_libraries(kagu_boot PRIVATE ws2_32)
endif()
