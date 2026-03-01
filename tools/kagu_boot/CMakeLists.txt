# kagu_boot - KaguOS emulator

add_executable(kagu_boot
    src/main_boot.cpp
    src/cpu.cpp
    src/ram.cpp
    src/interrupt_handler.cpp
    src/disk.cpp
    src/display.cpp
    src/input.cpp
)

target_include_directories(kagu_boot PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(kagu_boot PRIVATE
    kagu::libkagu
)
