//
// Created by ich on 11/1/21.
//

#include <iostream>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
//int simpleAdd(int a, int b);
#include <thread>

int main(int argc, char *argv[]) {
    std::jthread gui{
        [argc, argv] () mutable {
            QGuiApplication app(argc, argv);
            QQmlApplicationEngine engine;

            const QUrl url(u"qrc:/trollsar/view/qml/MainWindow.qml"_qs);

            engine.load(url);
            return app.exec();
        }
    };
}
