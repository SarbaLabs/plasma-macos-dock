add_executable(dockbluritemtest
    dockbluritemtest.cpp
    ../src/dockbluritem.cpp
    ../src/dockbluritem.h
)
target_include_directories(dockbluritemtest PRIVATE fakes ../src)
target_link_libraries(dockbluritemtest PRIVATE Qt6::Quick Qt6::Qml Qt6::Test Plasma::Plasma)
target_compile_definitions(dockbluritemtest PRIVATE DOCK_QML_DIR="${CMAKE_SOURCE_DIR}/contents/ui")
add_test(NAME dockbluritem COMMAND dockbluritemtest)
set_tests_properties(dockbluritem PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
)
