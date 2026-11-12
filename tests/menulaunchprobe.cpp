// SPDX-License-Identifier: GPL-2.0-or-later
#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QFile output(qEnvironmentVariable("DOCK_MENU_TEST_OUTPUT"));
    if (!output.open(QIODevice::WriteOnly)) {
        return 1;
    }
    output.write(QJsonDocument(QJsonArray::fromStringList(app.arguments().mid(1))).toJson());
    return 0;
}
