/*
    SPDX-FileCopyrightText: 2013-2016 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>

class ApplicationMenuBackend : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QVariantList jumpListActions(const QUrl &launcherUrl, QObject *parent);
    Q_INVOKABLE QVariantList placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent);
    Q_INVOKABLE QVariantList recentDocumentActions(const QUrl &launcherUrl, QObject *parent);

Q_SIGNALS:
    void showAllPlaces();

private:
    static QUrl tryDecodeApplicationsUrl(const QUrl &launcherUrl);
    static QStringList applicationCategories(const QUrl &launcherUrl);
    static bool historyAllowed(const QString &agent);
    void handleRecentDocumentAction() const;
};
