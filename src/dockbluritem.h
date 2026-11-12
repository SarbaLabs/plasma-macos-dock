/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QPointer>
#include <QQuickItem>
#include <QRectF>
#include <QRegion>
#include <QTimer>
#include <qqmlregistration.h>

class QQuickWindow;

class DockBlurItem : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(DockBlurArea)
    Q_PROPERTY(bool blurEnabled READ blurEnabled WRITE setBlurEnabled NOTIFY blurEnabledChanged)
    Q_PROPERTY(qreal cornerRadius READ cornerRadius WRITE setCornerRadius NOTIFY cornerRadiusChanged)
    Q_PROPERTY(qreal saturation READ saturation WRITE setSaturation NOTIFY saturationChanged)
    Q_PROPERTY(qreal contrast READ contrast WRITE setContrast NOTIFY contrastChanged)
    Q_PROPERTY(qreal intensity READ intensity WRITE setIntensity NOTIFY intensityChanged)

public:
    explicit DockBlurItem(QQuickItem *parent = nullptr);
    ~DockBlurItem() override;

    bool blurEnabled() const;
    void setBlurEnabled(bool enabled);

    qreal cornerRadius() const;
    void setCornerRadius(qreal radius);

    qreal saturation() const;
    void setSaturation(qreal val);

    qreal contrast() const;
    void setContrast(qreal val);

    qreal intensity() const;
    void setIntensity(qreal val);

Q_SIGNALS:
    void blurEnabledChanged();
    void cornerRadiusChanged();
    void saturationChanged();
    void contrastChanged();
    void intensityChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

public Q_SLOTS:
    void updateBlurRegion();
    void scheduleBlurRestore();

private:
    void clearBlurRegion();
    void trackWindow(QQuickWindow *newWindow);

    bool m_blurEnabled = true;
    qreal m_cornerRadius = 0.0;
    qreal m_saturation = 1.0;
    qreal m_contrast = 1.0;
    qreal m_intensity = 1.0;
    QRect m_lastAppliedRect;
    bool m_effectsApplied = false;
    bool m_surfaceBeingDestroyed = false;
    QTimer m_restoreTimer;
    QPointer<QQuickWindow> m_trackedWindow;
};

