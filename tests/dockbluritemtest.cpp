// SPDX-License-Identifier: GPL-2.0-or-later
#include "dockbluritem.h"
#include <KWindowEffects>
#include <QExposeEvent>
#include <QGuiApplication>
#include <QHash>
#include <QPainterPath>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTest>
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
        QQmlEngine engine;
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
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    DockBlurItemTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "dockbluritemtest.moc"
