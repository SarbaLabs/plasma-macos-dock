// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library
function radius(width, height, custom, value) {
    const limit = Math.max(0, Math.min(width, height) / 2);
    return custom ? Math.max(0, Math.min(limit, Number(value) || 0)) : limit * 2 / 3;
}
function boundary(pinned) {
    for (let i = 1; i < pinned.length; ++i) {
        if (pinned[i] !== pinned[i - 1]) return i;
    }
    return -1;
}
function gapAtEnd(vertical, reversed, rtl) {
    return vertical ? reversed : reversed !== rtl;
}
// Geometry changes only with capsule size/radius, not pointer movement.
function roundedPath(w, h, r) {
    r = radius(w, h, true, r);
    if (r === 0) return `M0 0 H${w} V${h} H0 Z`;
    return `M${r} 0 H${w-r} A${r} ${r} 0 0 1 ${w} ${r} V${h-r} A${r} ${r} 0 0 1 ${w-r} ${h} H${r} A${r} ${r} 0 0 1 0 ${h-r} V${r} A${r} ${r} 0 0 1 ${r} 0 Z`;
}
