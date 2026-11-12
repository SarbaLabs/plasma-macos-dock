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

if(BUILD_NATIVE_MENUS)
    find_program(KBUILDSYCOCA_EXECUTABLE kbuildsycoca6 REQUIRED)
    add_executable(menulaunchprobe menulaunchprobe.cpp)
    target_link_libraries(menulaunchprobe PRIVATE Qt6::Core)
    add_executable(applicationmenutest applicationmenutest.cpp)
    target_link_libraries(applicationmenutest PRIVATE dockmenubackend Qt6::Test Qt6::Qml)
    target_compile_definitions(applicationmenutest PRIVATE
        DOCK_MENU_PROBE="$<TARGET_FILE:menulaunchprobe>"
        DOCK_KBUILDSYCOCA="${KBUILDSYCOCA_EXECUTABLE}"
        DOCK_QML_DIR="${CMAKE_SOURCE_DIR}/contents/ui"
        DOCK_MENU_IMPORTS="${test_plugin_dir}")
    add_dependencies(applicationmenutest dockmenuplugin menulaunchprobe)
    set(menu_module_dir "${test_plugin_dir}/com/github/mattanis/macosdock/menus")
    add_custom_command(TARGET applicationmenutest POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "${menu_module_dir}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_FILE:dockmenuplugin>" "${menu_module_dir}/"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_SOURCE_DIR}/src/menus/qmldir" "${menu_module_dir}/")
    find_program(DBUS_RUN_SESSION_EXECUTABLE dbus-run-session REQUIRED)
    add_test(NAME applicationmenu COMMAND ${DBUS_RUN_SESSION_EXECUTABLE} -- $<TARGET_FILE:applicationmenutest>)
    add_test(NAME applicationmenu-qml-native COMMAND applicationmenutest optionalQmlBridge)
    set_tests_properties(applicationmenu PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
    set_tests_properties(applicationmenu-qml-native PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;DOCK_TEST_NATIVE_MENUS=1")
endif()

find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME installer-workflow COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/installtest.py ${CMAKE_SOURCE_DIR})
