add_library(FileSearchEngine SHARED
  src/FastSearchEngine.cpp
  src/SearchEngine_c_api.cpp
)

target_include_directories(FileSearchEngine PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_features(FileSearchEngine PUBLIC cxx_std_20)
target_compile_definitions(FileSearchEngine PRIVATE FILESEARCHENGINE_EXPORTS)

if (MSVC)
  target_compile_options(FileSearchEngine PRIVATE /utf-8)
endif()

# 必要なら明示リンク（FastSearchEngine.h に pragma comment あり）
target_link_libraries(FileSearchEngine PRIVATE shlwapi)

