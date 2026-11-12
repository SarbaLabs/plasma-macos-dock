add_executable(dockbluritemtest
    dockbluritemtest.cpp
    ../src/dockbluritem.cpp
    ../src/dockbluritem.h
)
target_include_directories(dockbluritemtest PRIVATE fakes ../src)
target_link_libraries(dockbluritemtest PRIVATE Qt6::Quick Qt6::Qml Qt6::Test Plasma::Plasma)
target_compile_definitions(dockbluritemtest PRIVATE DOCK_QML_DIR="${CMAKE_SOURCE_DIR}/contents/ui")
set(test_plugin_dir "${CMAKE_CURRENT_BINARY_DIR}/installed-qml")
set(test_module_dir "${test_plugin_dir}/com/github/mattanis/macosdock/blur")
target_compile_definitions(dockbluritemtest PRIVATE DOCK_TEST_PLUGIN_DIR="${test_plugin_dir}")
add_dependencies(dockbluritemtest dockblurplugin)
add_custom_command(TARGET dockbluritemtest POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "${test_module_dir}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:dockblurplugin>" "${test_module_dir}/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/src/qmldir" "${test_module_dir}/"
    VERBATIM
)
add_test(NAME dockbluritem COMMAND dockbluritemtest)
set_tests_properties(dockbluritem PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
)
