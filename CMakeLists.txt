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
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS WindowSystem)

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
)

# Install QML module plugin and qmldir
install(TARGETS dockblurplugin
    DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/blur
)
install(FILES src/qmldir
    DESTINATION ${KDE_INSTALL_QMLDIR}/com/github/mattanis/macosdock/blur
)

# Option to only build/install the C++ plugin (useful when the plasmoid is installed from KDE Store)
option(BUILD_PLUGIN_ONLY "Build and install only the C++ blur plugin without installing plasmoid files" OFF)

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

