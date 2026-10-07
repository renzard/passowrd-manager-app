// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7

// Colour constants for the "Onyx" theme: near-black canvas, glossy graphite
// cards, pure white accent (monochrome).
QtObject {
    readonly property color background: "#0b0b0c"
    readonly property color card: "#19191b"
    readonly property color cardTop: "#222224"
    readonly property color cardBottom: "#161618"
    readonly property color cardPressed: "#262629"
    readonly property color pill: "#1c1c1e"
    readonly property color tile: "#2b2b2e"
    readonly property color track: "#2b2b2e"
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property color text: "#ffffff"
    readonly property color secondaryText: "#8e8e93"
    readonly property color accent: "#ffffff"
    readonly property color accentText: "#0b0b0c"
}
