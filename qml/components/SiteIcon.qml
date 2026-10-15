// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3

// Entry tile: shows the site's icon (see backend/favicon.py) on a light plate
// when one has been downloaded, and falls back to the coloured letter tile.
Rectangle {
    id: tile
    property string iconPath: ""
    property string letter: "?"
    property color tileColor: "#555555"
    property color letterColor: "#ffffff"
    property real corner: width / 2
    property bool badge: false          // gold star = favourite
    readonly property bool hasIcon: img.status === Image.Ready

    radius: corner
    color: tileColor

    Label {
        anchors.centerIn: parent
        visible: !tile.hasIcon
        text: tile.letter
        color: tile.letterColor
        font.bold: true
        fontSize: "large"
    }

    // White plate keeps dark / transparent icons readable on dark themes
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: "#ffffff"
        visible: tile.hasIcon
        Image {
            id: img
            anchors { fill: parent; margins: parent.width * 0.2 }
            source: tile.iconPath !== "" ? "file://" + tile.iconPath : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
    }

    Rectangle {
        visible: tile.badge
        width: Math.max(units.gu(2), tile.width * 0.42); height: width; radius: width / 2
        x: tile.width - width * 0.75
        y: -width * 0.25
        color: "#f5b301"
        border.width: units.dp(1.5)
        border.color: "#1c1c1c"
        Icon {
            anchors.centerIn: parent
            width: parent.width * 0.62; height: width
            name: "starred"
            color: "#ffffff"
        }
    }
}
