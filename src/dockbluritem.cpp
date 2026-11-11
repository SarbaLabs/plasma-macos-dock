/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "dockbluritem.h"

#include <KWindowEffects>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QQuickWindow>

DockBlurItem::DockBlurItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, false);
    m_restoreTimer.setSingleShot(true);
    m_restoreTimer.setInterval(0);
    connect(&m_restoreTimer, &QTimer::timeout, this, [this] {
        if (!m_trackedWindow || m_surfaceBeingDestroyed || !m_trackedWindow->isVisible()
            || !m_trackedWindow->isExposed() || !isVisible() || !m_blurEnabled) {
            return;
        }
        // KWindowSystem also caches regions. Reset both effects before restoring
        // them, after the panel has processed the triggering event/signal.
        clearBlurRegion();
        updateBlurRegion();
        m_trackedWindow->update();
    });
    connect(this, &QQuickItem::windowChanged, this, &DockBlurItem::trackWindow);
    trackWindow(window());
}

DockBlurItem::~DockBlurItem()
{
    m_restoreTimer.stop();
    // QQuickItem emits windowChanged while detaching in its base destructor.
    disconnect(this, &QQuickItem::windowChanged, this, &DockBlurItem::trackWindow);
    if (m_trackedWindow) {
        m_trackedWindow->removeEventFilter(this);
        disconnect(m_trackedWindow.data(), nullptr, this, nullptr);
    }
    clearBlurRegion();
}

bool DockBlurItem::blurEnabled() const
{
    return m_blurEnabled;
}

void DockBlurItem::setBlurEnabled(bool enabled)
{
    if (m_blurEnabled != enabled) {
        m_blurEnabled = enabled;
        Q_EMIT blurEnabledChanged();
        updateBlurRegion();
    }
}

qreal DockBlurItem::cornerRadius() const
{
    return m_cornerRadius;
}

void DockBlurItem::setCornerRadius(qreal radius)
{
    if (!qFuzzyCompare(m_cornerRadius, radius)) {
        m_cornerRadius = radius;
        Q_EMIT cornerRadiusChanged();
        m_lastAppliedRect = QRect(); // force region recalculation
        updateBlurRegion();
    }
}

qreal DockBlurItem::saturation() const
{
    return m_saturation;
}

void DockBlurItem::setSaturation(qreal val)
{
    if (!qFuzzyCompare(m_saturation, val)) {
        m_saturation = val;
        Q_EMIT saturationChanged();
        m_lastAppliedRect = QRect();
        updateBlurRegion();
    }
}

qreal DockBlurItem::contrast() const
{
    return m_contrast;
}

void DockBlurItem::setContrast(qreal val)
{
    if (!qFuzzyCompare(m_contrast, val)) {
        m_contrast = val;
        Q_EMIT contrastChanged();
        m_lastAppliedRect = QRect();
        updateBlurRegion();
    }
}

qreal DockBlurItem::intensity() const
{
    return m_intensity;
}

void DockBlurItem::setIntensity(qreal val)
{
    if (!qFuzzyCompare(m_intensity, val)) {
        m_intensity = val;
        Q_EMIT intensityChanged();
        m_lastAppliedRect = QRect();
        updateBlurRegion();
    }
}

void DockBlurItem::trackWindow(QQuickWindow *newWindow)
{
    if (m_trackedWindow == newWindow) {
        return;
    }
    if (m_trackedWindow) {
        m_trackedWindow->removeEventFilter(this);
        disconnect(m_trackedWindow.data(), nullptr, this, nullptr);
        clearBlurRegion();
    }
    m_restoreTimer.stop();
    m_lastAppliedRect = QRect();
    m_effectsApplied = false;
    m_surfaceBeingDestroyed = false;
    m_trackedWindow = newWindow;
    if (m_trackedWindow) {
        m_trackedWindow->installEventFilter(this);
        connect(m_trackedWindow.data(), &QWindow::visibleChanged, this, &DockBlurItem::scheduleBlurRestore);
        // afterAnimating runs on the GUI thread, including with the threaded
        // render loop. Keep tracking ancestor transforms without KWin writes
        // when the mapped rectangle has not changed.
        connect(m_trackedWindow.data(), &QQuickWindow::afterAnimating, this, &DockBlurItem::updateBlurRegion);
        scheduleBlurRestore();
    }
}

void DockBlurItem::itemChange(ItemChange change, const ItemChangeData &value)
{
    if (change == ItemVisibleHasChanged) {
        updateBlurRegion();
    }
    QQuickItem::itemChange(change, value);
}

bool DockBlurItem::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_trackedWindow) {
        switch (event->type()) {
        case QEvent::PlatformSurface: {
            const auto *surfaceEvent = static_cast<QPlatformSurfaceEvent *>(event);
            if (surfaceEvent->surfaceEventType() == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed) {
                m_restoreTimer.stop();
                // The surface is still valid during this notification. Remove
                // remembered requests before teardown, including if this item
                // is deleted before the window creates another surface.
                clearBlurRegion();
                m_surfaceBeingDestroyed = true;
            } else {
                m_surfaceBeingDestroyed = false;
                scheduleBlurRestore();
            }
            break;
        }
        case QEvent::Show:
        case QEvent::Hide:
        case QEvent::Expose:
        case QEvent::Move:
        case QEvent::Resize:
            scheduleBlurRestore();
            break;
        default:
            break;
        }
    }
    return QQuickItem::eventFilter(watched, event);
}

void DockBlurItem::scheduleBlurRestore()
{
    m_lastAppliedRect = QRect();
    // A single queued pass coalesces notifications and runs after PanelView's
    // own blur/contrast updates. No polling or render-thread effect calls.
    if (!m_restoreTimer.isActive()) {
        m_restoreTimer.start();
    }
}

void DockBlurItem::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    updateBlurRegion();
}

void DockBlurItem::clearBlurRegion()
{
    if (m_trackedWindow && !m_surfaceBeingDestroyed) {
        KWindowEffects::enableBlurBehind(m_trackedWindow.data(), false);
        KWindowEffects::enableBackgroundContrast(m_trackedWindow.data(), false);
    }
    m_lastAppliedRect = QRect();
    m_effectsApplied = false;
}

void DockBlurItem::updateBlurRegion()
{
    if (!m_trackedWindow || m_surfaceBeingDestroyed) {
        return;
    }
    if (!isVisible() || !m_blurEnabled || width() <= 0 || height() <= 0) {
        if (m_effectsApplied) {
            clearBlurRegion();
        }
        return;
    }
    if (!m_trackedWindow->isVisible() || !m_trackedWindow->isExposed() || m_restoreTimer.isActive()) {
        return;
    }

    const QRectF mappedRectF = mapRectToScene(boundingRect());
    const QRect mappedRect = mappedRectF.toAlignedRect();

    if (mappedRect == m_lastAppliedRect) {
        return;
    }

    m_lastAppliedRect = mappedRect;

    QRegion blurRegion;
    if (m_cornerRadius > 0.0) {
        QPainterPath path;
        path.addRoundedRect(QRectF(mappedRect), m_cornerRadius, m_cornerRadius);
        blurRegion = QRegion(path.toFillPolygon().toPolygon());
    } else {
        blurRegion = QRegion(mappedRect);
    }

    KWindowEffects::enableBlurBehind(m_trackedWindow.data(), true, blurRegion);
    KWindowEffects::enableBackgroundContrast(m_trackedWindow.data(), true, m_contrast, m_intensity, m_saturation, blurRegion);
    m_effectsApplied = true;
}

