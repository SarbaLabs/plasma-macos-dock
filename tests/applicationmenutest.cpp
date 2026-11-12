// SPDX-License-Identifier: GPL-2.0-or-later
#include "applicationmenubackend.h"
#include <KConfigGroup>
#include <KFilePlacesModel>
#include <KService>
#include <KSharedConfig>
#include <QAction>
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QImage>
#include <QJSValue>
#include <QMenu>
#include <QPointer>
#include <QProcess>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

class ApplicationMenuTest : public QObject
{
    Q_OBJECT
    QTemporaryDir files;
    QUrl launcher;
    ApplicationMenuBackend backend;

    static QList<QAction *> flatten(const QVariantList &values)
    {
        QList<QAction *> result;
        for (const auto &value : values) {
            auto *action = value.value<QAction *>();
            if (!action) continue;
            result.append(action);
            if (action->menu()) result.append(action->menu()->actions());
        }
        return result;
    }

    void launchAndCheck(QAction *action, const QStringList &expected)
    {
        const QString output = files.path() + QStringLiteral("/arguments.json");
        QFile::remove(output);
        qputenv("DOCK_MENU_TEST_OUTPUT", output.toUtf8());
        action->trigger();
        QTRY_VERIFY_WITH_TIMEOUT(QFile::exists(output), 10000);
        QFile f(output);
        QVERIFY(f.open(QIODevice::ReadOnly));
        QTRY_VERIFY(f.size() > 0);
        QCOMPARE(QJsonDocument::fromJson(f.readAll()).array(), QJsonArray::fromStringList(expected));
    }

private Q_SLOTS:
    void initTestCase()
    {
        QVERIFY(files.isValid());
        const QString icons = files.path() + QStringLiteral("/icons/test/16x16/actions");
        QVERIFY(QDir().mkpath(icons));
        QFile theme(files.path() + QStringLiteral("/icons/test/index.theme"));
        QVERIFY(theme.open(QIODevice::WriteOnly));
        theme.write("[Icon Theme]\nName=Test\nDirectories=16x16/actions\n[16x16/actions]\nSize=16\nType=Fixed\nContext=Actions\n");
        theme.close();
        QImage icon(16, 16, QImage::Format_ARGB32);
        icon.fill(Qt::blue);
        QVERIFY(icon.save(icons + QStringLiteral("/window-new.png")));
        QIcon::setThemeSearchPaths({files.path() + QStringLiteral("/icons")});
        QIcon::setThemeName(QStringLiteral("test"));
        const QString apps = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
        const QString menus = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/menus");
        QVERIFY(QDir().mkpath(apps));
        QVERIFY(QDir().mkpath(menus));
        QFile menu(menus + QStringLiteral("/applications.menu"));
        QVERIFY(menu.open(QIODevice::WriteOnly));
        menu.write("<!DOCTYPE Menu PUBLIC '-//freedesktop//DTD Menu 1.0//EN' 'http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd'><Menu><Name>Applications</Name><DefaultAppDirs/><Include><All/></Include></Menu>");
        menu.close();
        const QString path = apps + QStringLiteral("/dock-menu-test.desktop");
        QFile desktop(path);
        QVERIFY(desktop.open(QIODevice::WriteOnly));
        desktop.write("[Desktop Entry]\nType=Application\nName=Menu Test\nIcon=system-file-manager\nCategories=FileManager;\nMimeType=inode/directory;\nExec=\"" DOCK_MENU_PROBE "\" %U\nActions=Private;Profile;Hidden;\n\n[Desktop Action Private]\nName=New Private Window\nIcon=window-new\nExec=\"" DOCK_MENU_PROBE "\" --private\n\n[Desktop Action Profile]\nName=Open Profile Manager\nExec=\"" DOCK_MENU_PROBE "\" --profile \"Profile With Spaces\"\n\n[Desktop Action Hidden]\nName=Hidden Action\nNoDisplay=true\nExec=true\n");
        desktop.close();
        QCOMPARE(QProcess::execute(QStringLiteral(DOCK_KBUILDSYCOCA), {QStringLiteral("--noincremental")}), 0);
        launcher = QUrl::fromLocalFile(path);
        QVERIFY(KService::serviceByDesktopPath(path));
    }

    void desktopActionsAndLifetime()
    {
        auto *owner = new QObject;
        const auto values = backend.jumpListActions(launcher, owner);
        QCOMPARE(values.size(), 2);
        QCOMPARE(backend.jumpListActions(QUrl(QStringLiteral("applications:dock-menu-test.desktop")), owner).size(), 2);
        auto actions = flatten(values);
        QCOMPARE(actions[0]->text(), QStringLiteral("New Private Window"));
        QCOMPARE(actions[0]->icon().name(), QStringLiteral("window-new"));
        QCOMPARE(actions[1]->text(), QStringLiteral("Open Profile Manager"));
        QPointer<QAction> guarded = actions[0];
        delete owner;
        QVERIFY(guarded.isNull());
    }

    void desktopActionLaunches()
    {
        QObject owner;
        const auto actions = flatten(backend.jumpListActions(launcher, &owner));
        QCOMPARE(actions.size(), 2);
        launchAndCheck(actions[0], {QStringLiteral("--private")});
        launchAndCheck(actions[1], {QStringLiteral("--profile"), QStringLiteral("Profile With Spaces")});
    }

    void placesAndStructuredUrls()
    {
        KFilePlacesModel places;
        const QUrl local = QUrl::fromLocalFile(files.path() + QStringLiteral("/A folder with spaces"));
        QVERIFY(QDir().mkpath(local.toLocalFile()));
        const QUrl remote(QStringLiteral("sftp://example.invalid/A%20remote%20folder"));
        places.addPlace(QStringLiteral("Dock local test"), local, QStringLiteral("folder"));
        places.addPlace(QStringLiteral("Dock remote test"), remote, QStringLiteral("folder-network"));
        places.addPlace(QStringLiteral("Dock hidden test"), QUrl::fromLocalFile(files.path()+QStringLiteral("/hidden")));
        for (int i = 0; i < places.rowCount(); ++i) {
            const auto idx = places.index(i, 0);
            if (places.text(idx) == QStringLiteral("Dock hidden test")) places.setPlaceHidden(idx, true);
        }
        QObject owner;
        const auto actions = flatten(backend.placesActions(launcher, true, &owner));
        QAction *localAction = nullptr;
        QAction *remoteAction = nullptr;
        bool hasSubmenu = false;
        for (auto *action : actions) {
            QVERIFY(action->text() != QStringLiteral("Dock hidden test"));
            if (action->text() == QStringLiteral("Dock local test")) localAction = action;
            if (action->text() == QStringLiteral("Dock remote test")) remoteAction = action;
            hasSubmenu |= action->menu() != nullptr;
        }
        QVERIFY(localAction);
        QVERIFY(remoteAction);
        QVERIFY(hasSubmenu);

        for (int i = 0; i < 9; ++i) {
            places.addPlace(QStringLiteral("Extra %1").arg(i), QUrl::fromLocalFile(files.path()+QStringLiteral("/extra%1").arg(i)));
        }
        const auto limited = backend.placesActions(launcher, false, &owner);
        QCOMPARE(limited.size(), 6);
        QSignalSpy more(&backend, &ApplicationMenuBackend::showAllPlaces);
        limited.last().value<QAction *>()->trigger();
        QCOMPARE(more.count(), 1);
        QVERIFY(backend.placesActions(launcher, true, &owner).size() > 7);
    }

    void placeLaunches()
    {
        KFilePlacesModel places;
        const QUrl local = QUrl::fromLocalFile(files.path() + QStringLiteral("/Launch folder with spaces"));
        QVERIFY(QDir().mkpath(local.toLocalFile()));
        const QUrl remote(QStringLiteral("sftp://example.invalid/Launch%20remote%20folder"));
        places.addPlace(QStringLiteral("Launch local"), local);
        places.addPlace(QStringLiteral("Launch remote"), remote);
        QObject owner;
        const auto actions = flatten(backend.placesActions(launcher, true, &owner));
        int tested = 0;
        for (auto *action : actions) {
            if (action->text() == QStringLiteral("Launch local")) {
                launchAndCheck(action, {local.toLocalFile()});
                ++tested;
            } else if (action->text() == QStringLiteral("Launch remote")) {
                launchAndCheck(action, {remote.toString()});
                ++tested;
            }
        }
        QCOMPARE(tested, 2);
    }

    void missingActionsAndPrivacy()
    {
        QObject owner;
        QVERIFY(backend.jumpListActions(QUrl(QStringLiteral("applications:nonexistent-dock-test.desktop")), &owner).isEmpty());
        QVERIFY(backend.jumpListActions(launcher, nullptr).isEmpty());
        QVERIFY(backend.placesActions(QUrl(QStringLiteral("https://example.invalid/app.desktop")), true, &owner).isEmpty());
        QFile desktop(QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)+QStringLiteral("/empty.desktop"));
        QVERIFY(desktop.open(QIODevice::WriteOnly));
        desktop.write("[Desktop Entry]\nType=Application\nName=Empty\nExec=true\n");
        desktop.close();
        QCOMPARE(QProcess::execute(QStringLiteral(DOCK_KBUILDSYCOCA), {QStringLiteral("--noincremental")}), 0);
        const auto empty = QUrl::fromLocalFile(desktop.fileName());
        QVERIFY(backend.jumpListActions(empty, &owner).isEmpty());
        QVERIFY(backend.placesActions(empty, true, &owner).isEmpty());
        auto config = KSharedConfig::openConfig(QStringLiteral("kactivitymanagerd-pluginsrc"));
        KConfigGroup privacy(config, QStringLiteral("Plugin-org.kde.ActivityManager.Resources.Scoring"));
        privacy.writeEntry("what-to-remember", 2);
        config->sync();
        QVERIFY(backend.recentDocumentActions(launcher, &owner).isEmpty());
        privacy.writeEntry("what-to-remember", 1);
        privacy.writeEntry("blocked-by-default", false);
        privacy.writeEntry("blocked-applications", QStringList{QStringLiteral("dock-menu-test")});
        config->sync();
        QVERIFY(backend.recentDocumentActions(launcher, &owner).isEmpty());
    }

    void optionalQmlBridge()
    {
        QQmlEngine engine;
        if (qEnvironmentVariableIsSet("DOCK_TEST_NATIVE_MENUS")) {
            engine.addImportPath(QStringLiteral(DOCK_MENU_IMPORTS));
        }
        QTemporaryDir qmlFixture;
        QString bridgePath = QStringLiteral(DOCK_QML_DIR "/ApplicationMenuBridge.qml");
        if (!qEnvironmentVariableIsSet("DOCK_TEST_NATIVE_MENUS")) {
            // A missing optional component must also work on machines where the
            // native module has already been installed globally.
            const QString copy = qmlFixture.path() + QStringLiteral("/ApplicationMenuBridge.qml");
            QVERIFY(QFile::copy(bridgePath, copy));
            bridgePath = copy;
        }
        QQmlComponent component(&engine, QUrl::fromLocalFile(bridgePath));
        QScopedPointer<QObject> bridge(component.create());
        QVERIFY2(bridge, qPrintable(component.errorString()));
        QCOMPARE(bridge->property("available").toBool(), qEnvironmentVariableIsSet("DOCK_TEST_NATIVE_MENUS"));
        {
            QVariant result;
            QVERIFY(QMetaObject::invokeMethod(bridge.data(), "jumpListActions", Q_RETURN_ARG(QVariant, result),
                Q_ARG(QVariant, launcher), Q_ARG(QVariant, QVariant::fromValue(bridge.data()))));
            if (result.metaType() == QMetaType::fromType<QJSValue>()) {
                QVERIFY(result.value<QJSValue>().isArray());
                result = result.value<QJSValue>().toVariant();
            }
            QVERIFY(result.canConvert<QVariantList>());
            QCOMPARE(result.toList().size(), bridge->property("available").toBool() ? 2 : 0);
            if (bridge->property("available").toBool()) {
                QSignalSpy showAll(bridge.data(), SIGNAL(showAllPlaces()));
                auto *native = bridge->property("nativeBackend").value<QObject *>();
                QVERIFY(QMetaObject::invokeMethod(native, "showAllPlaces"));
                QCOMPARE(showAll.count(), 1);
            }
        }
    }
};

int main(int argc, char **argv)
{
    QTemporaryDir environment;
    if (!environment.isValid()) return 1;
    // Never access the developer's Places/history/configuration.
    qputenv("HOME", environment.path().toUtf8());
    qputenv("XDG_DATA_HOME", (environment.path()+QStringLiteral("/data")).toUtf8());
    qputenv("XDG_CONFIG_HOME", (environment.path()+QStringLiteral("/config")).toUtf8());
    qputenv("XDG_CACHE_HOME", (environment.path()+QStringLiteral("/cache")).toUtf8());
    QApplication app(argc, argv);
    ApplicationMenuTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "applicationmenutest.moc"
