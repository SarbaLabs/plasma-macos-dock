// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function number(config, name, fallback, min, max) {
    const value = config && config[name] !== undefined ? Number(config[name]) : fallback;
    return Math.max(min, Math.min(max, Number.isFinite(value) ? value : fallback));
}
function flag(config, name, fallback) {
    return config && config[name] !== undefined ? Boolean(config[name]) : fallback;
}
function mode(config) {
    const value = config ? config.indicatorMode : 0;
    return value === 1 || value === 2 ? value : 0;
}
function nativeEnabled(setting, mode, popup) {
    return setting === 1 || (setting !== 2 && (mode === 1 || popup));
}
function edge(config, effectiveEdge) {
    return flag(config, "indicatorOverride", false)
        ? Math.round(number(config, "indicatorEdge", 0, 0, 3)) : effectiveEdge;
}
function count(running, grouped, children) {
    return running ? (grouped ? Math.max(1, Math.floor(Number(children) || 0)) : 1) : 0;
}

// A bounded list: at most eight windows and one overflow marker, regardless
// of the actual group size. Geometry never contributes to the task's layout.
function segments(config, count, activeIndex, hovered, available, padding) {
    if (!flag(config, "customIndicatorsEnabled", true) || count <= 0) return [];
    const limit = Math.round(number(config, "indicatorMaxSegments", 4, 1, 8));
    const shown = Math.min(count, limit);
    const plus = flag(config, "indicatorOverflow", true) && count > shown;
    const style = Math.round(number(config, "indicatorStyle", 0, 0, 2));
    const spacing = number(config, "indicatorSpacing", 2, 0, 16);
    const result = [];
    for (let i = 0; i < shown + (plus ? 1 : 0); ++i) {
        const overflow = i === shown;
        const active = i === activeIndex || ((overflow || (!plus && i === shown - 1)) && activeIndex >= shown);
        let length = number(config, "indicatorLength", 12, 1, 160);
        let thickness = number(config, "indicatorThickness", 4, 1, 24);
        if (count > 1 && flag(config, "indicatorGroupSeparate", false)) {
            length = number(config, "indicatorGroupLength", 8, 1, 160);
            thickness = number(config, "indicatorGroupThickness", 4, 1, 24);
        }
        if (active && flag(config, "indicatorResizeActive", true)) {
            length = number(config, "indicatorActiveLength", 20, 1, 160);
            thickness = number(config, "indicatorActiveThickness", 5, 1, 24);
        }
        if (hovered && flag(config, "indicatorResizeHover", false)) {
            const separate = flag(config, "indicatorHoverSeparate", true);
            length = number(config, separate ? "indicatorHoverLength" : "indicatorActiveLength", 20, 1, 160);
            thickness = number(config, separate ? "indicatorHoverThickness" : "indicatorActiveThickness", 5, 1, 24);
        }
        thickness = Math.min(thickness, Math.max(1, padding));
        if (style === 0 || overflow) length = thickness;
        else if (style === 1) length /= shown;
        result.push({active: active, overflow: overflow, index: i, length: length, thickness: thickness});
    }
    const gap = Math.min(spacing, Math.max(0, available) / (result.length * 2));
    const total = result.reduce((sum, s) => sum + s.length, 0);
    const scale = Math.min(1, Math.max(0, available - gap * (result.length - 1)) / Math.max(1, total));
    const used = total * scale + gap * (result.length - 1);
    let offset = (available - used) / 2;
    for (const segment of result) {
        segment.length *= scale;
        if (style === 0 || segment.overflow) segment.thickness = Math.min(segment.thickness, segment.length);
        segment.offset = offset;
        offset += segment.length + gap;
    }
    return result;
}
function baseColor(mode, accent, dominant, custom) {
    if (mode === 2 && custom) return custom;
    if (mode === 1 && dominant && dominant.a > 0) return dominant;
    return accent;
}
function segmentColor(base, active, grouped, minimized, config) {
    let c = base;
    if (minimized && flag(config, "indicatorDesaturate", false)) c = Qt.hsla(c.hslHue, 0, c.hslLightness, c.a);
    const dim = !active && (flag(config, "indicatorDimInactive", true)
        || (grouped && flag(config, "indicatorHighlightActive", true)));
    return Qt.rgba(c.r, c.g, c.b, c.a * (dim ? number(config, "indicatorInactiveOpacity", 55, 0, 100) / 100 : 1));
}
