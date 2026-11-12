cmake_minimum_required(VERSION 3.16)

project(plasma-macos-dock LANGUAGES CXX)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core Quick Gui Qml)
# Explicit Config/CoreAddons discovery also supports older Plasma CMake exports.
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS WindowSystem Config CoreAddons)
find_package(Plasma REQUIRED)

option(BUILD_NATIVE_MENUS "Build optional native application menu support" ON)
if(BUILD_NATIVE_MENUS)
    find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Widgets)
    find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS KIO Service I18n Notifications)
    find_package(PlasmaActivitiesStats REQUIRED)
    add_library(dockmenubackend STATIC src/applicationmenubackend.cpp src/applicationmenubackend.h)
    set_target_properties(dockmenubackend PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_include_directories(dockmenubackend PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
    target_link_libraries(dockmenubackend PUBLIC
        Qt6::Widgets KF6::KIOFileWidgets KF6::KIOGui KF6::Service
        KF6::I18n KF6::Notifications Plasma::ActivitiesStats)
    add_library(dockmenuplugin SHARED src/menuplugin.cpp src/menuplugin.h)
    target_link_libraries(dockmenuplugin PRIVATE dockmenubackend Qt6::Qml)
    install(TARGETS dockmenuplugin
        DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/menus)
    install(FILES src/menus/qmldir
        DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/menus)
endif()

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Test)
    add_subdirectory(tests)
endif()

# Single self-contained QML extension plugin library
add_library(dockblurplugin SHARED
    src/blurplugin.h
    src/blurplugin.cpp
    src/dockbluritem.h
    src/dockbluritem.cpp
)

target_include_directories(dockblurplugin
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(dockblurplugin
    PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Gui
    Qt6::Qml
    KF6::WindowSystem
    Plasma::Plasma
)

# Install QML module plugin and qmldir
install(TARGETS dockblurplugin
    DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/blur
)
install(FILES src/qmldir
    DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/blur
)

# Option to only build/install the C++ plugin (useful when the plasmoid is installed from KDE Store)
option(BUILD_PLUGIN_ONLY "Build and install only the native plugins without installing plasmoid files" OFF)

if(NOT BUILD_PLUGIN_ONLY)
    # Install plasmoid applet package directly
    install(DIRECTORY contents
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/com.github.mattanis.macosdock
    )
    install(FILES metadata.json
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/com.github.mattanis.macosdock
    )

    # Install icon for widget explorer and system integration
    install(FILES assets/logo.png
        DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/256x256/apps
        RENAME com.github.mattanis.macosdock.png
    )
endif()

