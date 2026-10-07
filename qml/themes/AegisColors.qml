// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7

// Colour constants for the "Aegis" theme: near-black canvas, indigo/violet accent.
QtObject {
    readonly property color background: "#0a0b12"
    readonly property color card: "#12131d"
    readonly property color field: "#15172a"
    readonly property color nav: "#0d0e16"
    readonly property color border: Qt.rgba(1, 1, 1, 0.08)
    readonly property color text: "#ffffff"
    readonly property color secondaryText: "#8d92a8"
    readonly property color accent: "#6d5efc"
    readonly property color accentSoft: "#8b7bff"
    readonly property color accentText: "#ffffff"
    readonly property color good: "#22c88a"
    readonly property color warn: "#f5a524"
    readonly property color folder: "#5b8cff"
    readonly property var tileColors: ["#6d5efc", "#3b82f6", "#22c88a", "#f5a524", "#ec4899", "#ef4444", "#06b6d4"]
}
