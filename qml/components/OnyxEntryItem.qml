// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Glossy rounded row of the "Onyx" theme: letter tile, title, subtitle and a
// copy-password button on the right.
Item {
    id: item
    property string uuid: ""
    property string title: ""
    property string subtitle: ""
    property int order: 0
    property int run: 1

    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid)
    signal copyRequested(string uuid)

    height: units.gu(9.6)

    OnyxColors { id: c }

    opacity: ap.progress
    transform: Translate { x: ap.offset }
    Appear { id: ap; run: item.run; delay: 60 + Math.min(item.order, 8) * 60
             distance: units.gu(3); duration: 420 }

    Rectangle {
        id: card
        anchors { fill: parent; topMargin: units.gu(0.6); bottomMargin: units.gu(0.6) }
        radius: units.gu(2.4)
        border.width: units.dp(1)
        border.color: c.border
        gradient: Gradient {
            GradientStop { position: 0; color: area.pressed ? c.cardPressed : c.cardTop }
            GradientStop { position: 1; color: area.pressed ? c.cardPressed : c.cardBottom }
        }
        scale: area.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            id: tile
            anchors { left: parent.left; leftMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
            width: units.gu(5.4); height: width; radius: width / 2
            color: c.tile
            Label {
                anchors.centerIn: parent
                text: item.title.length ? item.title.charAt(0).toUpperCase() : "?"
                font.bold: true; fontSize: "large"; color: c.text
            }
        }
        Column {
            anchors { left: tile.right; leftMargin: units.gu(1.6); right: copyBtn.left
                      rightMargin: units.gu(0.5); verticalCenter: parent.verticalCenter }
            spacing: units.gu(0.4)
            Label { width: parent.width; text: item.title; font.bold: true; fontSize: "medium"
                    color: c.text; elide: Text.ElideRight }
            Label { width: parent.width; text: item.subtitle; fontSize: "x-small"
                    color: c.secondaryText; elide: Text.ElideRight }
        }
        Item {
            id: copyBtn
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: units.gu(6)
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.4); height: width
                name: "edit-copy"
                color: copyArea.pressed ? c.text : c.secondaryText
                scale: copyArea.pressed ? 0.8 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
            }
        }
    }

    MouseArea {
        id: area
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: units.gu(6) }
        onClicked: item.entryClicked(item.uuid)
        onPressAndHold: item.entryLongPressed(item.uuid)
    }
    MouseArea {
        id: copyArea
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: units.gu(6)
        onClicked: item.copyRequested(item.uuid)
    }
}
