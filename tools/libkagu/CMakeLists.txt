# libkagu - KaguOS shared headers (interface library)

add_library(libkagu INTERFACE)

target_include_directories(libkagu INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Alias for nicer target name
add_library(kagu::libkagu ALIAS libkagu)
