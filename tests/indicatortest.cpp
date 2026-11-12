// SPDX-License-Identifier: GPL-2.0-or-later
#include <QtQuickTest/quicktest.h>
#include <QQmlContext>
#include <QQmlEngine>
#include <KLocalizedContext>
#include <QStandardPaths>
#include <QFile>
#include <QXmlStreamReader>
#include <QVariantMap>

class IndicatorSetup : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        QFile schema(QStringLiteral(DOCK_CONFIG_SCHEMA));
        if (!schema.open(QIODevice::ReadOnly)) qFatal("Cannot open configuration schema");
        QXmlStreamReader xml(&schema);
        QVariantMap defaults;
        QString name;
        QString type;
        while (!xml.atEnd()) {
            xml.readNext();
            if (!xml.isStartElement()) continue;
            if (xml.name() == u"entry") {
                name = xml.attributes().value(u"name").toString();
                type = xml.attributes().value(u"type").toString();
            } else if (xml.name() == u"default") {
                const QString value = xml.readElementText();
                if (name.startsWith(u"indicator") || name == u"customIndicatorsEnabled"
                    || name == u"nativeGroupIndicator" || name == u"taskDecorations") {
                    defaults.insert(name, type == u"Bool" ? QVariant(value == u"true")
                        : type == u"Int" ? QVariant(value.toInt()) : QVariant(value));
                }
            }
        }
        if (xml.hasError()) qFatal("Invalid configuration schema");
        engine->rootContext()->setContextProperty(QStringLiteral("indicatorDefaults"), defaults);
        auto *localized = new KLocalizedContext(engine);
        localized->setTranslationDomain(QStringLiteral("plasma_applet_com.github.mattanis.macosdock"));
        engine->rootContext()->setContextObject(localized);
        engine->rootContext()->setContextProperty(QStringLiteral("testThemePath"), QStandardPaths::locate(
            QStandardPaths::GenericDataLocation, QStringLiteral("plasma/desktoptheme/default/widgets/tasks.svgz")));
    }
};
QUICK_TEST_MAIN_WITH_SETUP(indicators, IndicatorSetup)
#include "indicatortest.moc"
