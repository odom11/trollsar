cmake_minimum_required(VERSION 3.18)
find_package(Qt6 REQUIRED COMPONENTS Gui Quick)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)


qt_add_executable(trollsar)
target_sources(trollsar PRIVATE main.cpp)
target_link_libraries(trollsar PRIVATE Qt6::Gui Qt6::Quick)
set_target_properties(trollsar PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

qt_add_qml_module(trollsar
    URI trollsar
    VERSION 1.0
    QML_FILES view/qml/MainWindow.qml
)

