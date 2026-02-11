# kagu_asm - KaguOS assembler

add_executable(kagu_asm
    src/main_asm.cpp
    src/compiler.cpp
    src/lexer.cpp
    src/symbols.cpp
)

target_include_directories(kagu_asm PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(kagu_asm PRIVATE
    kagu::libkagu
)
