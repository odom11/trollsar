cmake_minimum_required(VERSION 3.18)
find_package(Qt6 REQUIRED COMPONENTS Gui Quick)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)


qt_add_executable(trollsar_main)
target_sources(trollsar_main PRIVATE
        main.cpp
        optix/driver.cpp
)
target_link_libraries(trollsar_main PRIVATE Qt6::Quick)
set_target_properties(trollsar_main PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

qt_add_qml_module(trollsar_main
    URI trollsar
    VERSION 1.0
    QML_FILES 
        view/qml/MainWindow.qml 
        view/qml/FramedImage.qml
    RESOURCES
        view/qml/img/world.png
)

