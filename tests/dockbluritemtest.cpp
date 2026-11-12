// SPDX-License-Identifier: GPL-2.0-or-later
#include "dockbluritem.h"
#include <KWindowEffects>
#include <Plasma/Theme>
#include <QExposeEvent>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QHash>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTest>
#include <QTemporaryDir>
#include <QThread>
#include <memory>

struct Effects {
    bool blur = false;
    bool contrast = false;
    int writes = 0;
    QRegion region;
    QRegion contrastRegion;
    qreal saturation = 1;
    qreal intensity = 1;
    qreal contrastValue = 1;
};
static QHash<QWindow *, Effects> effects;
static bool wrongThread = false;

namespace KWindowEffects {
void enableBlurBehind(QWindow *window, bool enabled, const QRegion &region)
{
    wrongThread |= QThread::currentThread() != qGuiApp->thread();
    auto &state = effects[window];
    state.blur = enabled;
    state.region = region;
    ++state.writes;
}
void enableBackgroundContrast(QWindow *window, bool enabled, qreal contrast,
                              qreal intensity, qreal saturation, const QRegion &region)
{
    wrongThread |= QThread::currentThread() != qGuiApp->thread();
    auto &state = effects[window];
    state.contrast = enabled;
    state.contrastValue = contrast;
    state.intensity = intensity;
    state.saturation = saturation;
    state.contrastRegion = region;
    ++state.writes;
}
}

class DockBlurItemTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void init()
    {
        effects.clear();
        wrongThread = false;
    }
    void cleanup()
    {
        QVERIFY(!wrongThread);
    }
    void cornerRadiusChangesWithoutGeometryChange()
    {
        QQuickWindow window;
        window.resize(200, 100);
        DockBlurItem item(window.contentItem());
        item.setSize(QSizeF(100, 40));
        window.show();
        QTRY_VERIFY(window.isExposed());
        for (qreal radius : {0., 5., 10., 20., 0.}) {
            item.setCornerRadius(radius);
            item.updateBlurRegion();
            QPainterPath path;
            path.addRoundedRect(QRectF(0, 0, 100, 40), radius, radius);
            const QRegion expected = radius == 0 ? QRegion(0, 0, 100, 40)
                : QRegion(path.toFillPolygon().toPolygon());
            QTRY_COMPARE(effects[&window].region, expected);
            QCOMPARE(effects[&window].contrastRegion, expected);
        }
    }
    void restoreWithoutPointerAndKeepCache()
    {
        QQuickWindow window;
        window.resize(400, 160);
        DockBlurItem item(window.contentItem());
        item.setSize(QSizeF(200, 60));
        item.setPosition(QPointF(40, 50));
        item.setCornerRadius(20);
        item.setSaturation(1.3);
        item.setContrast(0.9);
        item.setIntensity(1.1);
        window.show();
        QTRY_VERIFY(window.isExposed());
        QTRY_VERIFY(effects[&window].blur);
        QPainterPath path;
        path.addRoundedRect(QRectF(40, 50, 200, 60), 20, 20);
        const QRegion expected(path.toFillPolygon().toPolygon());
        QCOMPARE(effects[&window].region, expected);
        for (int cycle = 0; cycle < 20; ++cycle) {
            window.hide();
            QCoreApplication::processEvents();
            effects[&window].blur = false;
            effects[&window].contrast = false;
            window.show();
            QTRY_VERIFY(effects[&window].blur && effects[&window].contrast);
            QCOMPARE(effects[&window].region, expected);
            QCOMPARE(effects[&window].contrastRegion, expected);
            QCOMPARE(effects[&window].saturation, 1.3);
            QCOMPARE(effects[&window].contrastValue, 0.9);
            QCOMPARE(effects[&window].intensity, 1.1);
        }
        QTest::qWait(30);
        const int writes = effects[&window].writes;
        for (int frame = 0; frame < 20; ++frame) {
            window.update();
            item.updateBlurRegion();
            QTest::qWait(2);
        }
        QCOMPARE(effects[&window].writes, writes);
        for (int signal = 0; signal < 20; ++signal) {
            item.scheduleBlurRestore();
        }
        QTRY_COMPARE(effects[&window].writes, writes + 4);
        item.setBlurEnabled(false);
        QVERIFY(!effects[&window].blur && !effects[&window].contrast);
        item.scheduleBlurRestore();
        QTest::qWait(10);
        QVERIFY(!effects[&window].blur);
        item.setBlurEnabled(true);
        QTRY_VERIFY(effects[&window].blur);
        item.setVisible(false);
        QVERIFY(!effects[&window].blur);
        item.setVisible(true);
        QTRY_VERIFY(effects[&window].blur);
    }
    void exposureAndWindowTransfer()
    {
        QQuickWindow first;
        QQuickWindow second;
        first.resize(300, 100);
        second.resize(300, 100);
        first.show();
        second.show();
        QTRY_VERIFY(first.isExposed() && second.isExposed());
        auto item = std::make_unique<DockBlurItem>(first.contentItem());
        item->setSize(QSizeF(180, 50));
        QTRY_VERIFY(effects[&first].blur);
        effects[&first].blur = false;
        QExposeEvent exposed(QRegion(0, 0, 300, 100));
        QCoreApplication::sendEvent(&first, &exposed);
        QTRY_VERIFY(effects[&first].blur);
        QPlatformSurfaceEvent tearingDown(QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed);
        QCoreApplication::sendEvent(&first, &tearingDown);
        QVERIFY(!effects[&first].blur);
        const int writesDuringTeardown = effects[&first].writes;
        item->scheduleBlurRestore();
        QTest::qWait(10);
        QCOMPARE(effects[&first].writes, writesDuringTeardown);
        QPlatformSurfaceEvent created(QPlatformSurfaceEvent::SurfaceCreated);
        QCoreApplication::sendEvent(&first, &created);
        QTRY_VERIFY(effects[&first].blur);
        item->scheduleBlurRestore();
        item->setParentItem(second.contentItem());
        QTRY_VERIFY(effects[&second].blur);
        QVERIFY(!effects[&first].blur);
        item->scheduleBlurRestore();
        item.reset();
        QTest::qWait(10);
        QVERIFY(!effects[&second].blur);
    }
    void panelResetWhileWindowStaysVisible()
    {
        qmlRegisterType<DockBlurItem>("com.github.mattanis.macosdock.blur", 1, 0, "DockBlurArea");
        // An installed native module must not replace this test's registration:
        // its KWindowEffects calls bypass our recording backend.
        QVERIFY(qmlProtectModule("com.github.mattanis.macosdock.blur", 1));
        // Unversioned imports still resolve a qmldir. Shadow the installed
        // descriptor with a plugin-free module containing our registered type.
        QTemporaryDir testImports;
        QVERIFY(testImports.isValid());
        const QString modulePath = testImports.path() + QStringLiteral("/com/github/mattanis/macosdock/blur");
        QVERIFY(QDir().mkpath(modulePath));
        QFile qmldir(modulePath + QStringLiteral("/qmldir"));
        QVERIFY(qmldir.open(QIODevice::WriteOnly));
        const QByteArray descriptor("module com.github.mattanis.macosdock.blur\n");
        QCOMPARE(qmldir.write(descriptor), qint64(descriptor.size()));
        qmldir.close();
        QQmlEngine engine;
        // Reproduce the installed-plugin environment even on a clean CI runner.
        engine.addImportPath(QStringLiteral(DOCK_TEST_PLUGIN_DIR));
        engine.addImportPath(testImports.path());
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            Item {
                width: 200; height: 60
                property var panelMask: null
                property real floatingness: 0
                property bool touchingWindow: false
                BlurAreaBridge { anchors.fill: parent }
            }
        )", QUrl::fromLocalFile(QStringLiteral(DOCK_QML_DIR "/TestPanel.qml")));
        std::unique_ptr<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        auto root = qobject_cast<QQuickItem *>(object.get());
        QVERIFY(root);
        QQuickWindow window;
        window.resize(300, 100);
        root->setParentItem(window.contentItem());
        window.show();
        QTRY_VERIFY(effects[&window].blur);
        const char *properties[] = {"touchingWindow", "floatingness", "panelMask"};
        for (const char *property : properties) {
            effects[&window].blur = false;
            effects[&window].contrast = false;
            QVERIFY(root->setProperty(property, 1));
            QTRY_VERIFY(effects[&window].blur && effects[&window].contrast);
            QVERIFY(window.isVisible());
        }
        // Remove the QML item before its window; also covers loader teardown.
        object.reset();
        QVERIFY(!effects[&window].blur);
    }

    void themeChangesWhileStationary_data()
    {
        QTest::addColumn<bool>("panelConnectsFirst");
        QTest::newRow("panel-before-dock") << true;
        QTest::newRow("panel-after-dock") << false;
    }

    void themeChangesWhileStationary()
    {
        QFETCH(bool, panelConnectsFirst);
        QQuickWindow window;
        window.resize(300, 100);
        std::unique_ptr<Plasma::Theme> panelTheme;
        int panelResets = 0;
        const auto connectPanel = [&] {
            panelTheme = std::make_unique<Plasma::Theme>();
            // Match PanelView: theme updates clear NoBackground effects even
            // when window visibility, the mask and capsule geometry stay put.
            connect(panelTheme.get(), &Plasma::Theme::themeChanged, &window, [&] {
                KWindowEffects::enableBlurBehind(&window, false);
                KWindowEffects::enableBackgroundContrast(&window, false);
                ++panelResets;
            });
        };
        if (panelConnectsFirst) {
            connectPanel();
        }
        DockBlurItem item(window.contentItem());
        item.setSize(QSizeF(180, 50));
        item.setPosition(QPointF(30, 20));
        item.setCornerRadius(15);
        item.setSaturation(1.4);
        item.setContrast(0.8);
        item.setIntensity(1.2);
        if (!panelConnectsFirst) {
            connectPanel();
        }
        window.show();
        QTRY_VERIFY(window.isExposed());
        QTRY_VERIFY(effects[&window].blur);
        const QRegion expected = effects[&window].region;

        const auto changePalette = [] {
            // Exercise libplasma's real deferred colorsChanged -> themeChanged
            // path, without changing the test process's actual palette.
            QEvent paletteChange(QEvent::ApplicationPaletteChange);
            QCoreApplication::sendEvent(qGuiApp, &paletteChange);
        };
        for (int cycle = 0; cycle < 20; ++cycle) {
            const int previousResets = panelResets;
            changePalette();
            QTRY_VERIFY(panelResets > previousResets);
            QTRY_VERIFY(effects[&window].blur && effects[&window].contrast);
            QCOMPARE(effects[&window].region, expected);
            QCOMPARE(effects[&window].contrastRegion, expected);
            QCOMPARE(effects[&window].saturation, 1.4);
            QCOMPARE(effects[&window].contrastValue, 0.8);
            QCOMPARE(effects[&window].intensity, 1.2);
            QCOMPARE(item.position(), QPointF(30, 20));
            QCOMPARE(item.size(), QSizeF(180, 50));
        }

        window.hide();
        QCoreApplication::processEvents();
        int previousResets = panelResets;
        changePalette();
        QTRY_VERIFY(panelResets > previousResets);
        QTest::qWait(20);
        QVERIFY(!effects[&window].blur && !effects[&window].contrast);
        window.show();
        QTRY_VERIFY(effects[&window].blur && effects[&window].contrast);

        // A palette notification may arrive after a panel-animation restore.
        previousResets = panelResets;
        item.scheduleBlurRestore();
        QTimer::singleShot(0, &window, changePalette);
        QTRY_VERIFY(panelResets > previousResets);
        QTRY_VERIFY(effects[&window].blur && effects[&window].contrast);

        item.setBlurEnabled(false);
        previousResets = panelResets;
        changePalette();
        QTRY_VERIFY(panelResets > previousResets);
        QTest::qWait(20);
        QVERIFY(!effects[&window].blur && !effects[&window].contrast);
        item.setBlurEnabled(true);
        QTRY_VERIFY(effects[&window].blur);
        QTest::qWait(20);
        const int writes = effects[&window].writes;
        for (int frame = 0; frame < 10; ++frame) {
            window.update();
            QTest::qWait(2);
        }
        QCOMPARE(effects[&window].writes, writes);
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    DockBlurItemTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "dockbluritemtest.moc"
