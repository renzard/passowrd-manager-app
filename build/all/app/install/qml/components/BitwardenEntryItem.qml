// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Vault row used by the "Bitwarden" theme: round letter avatar, title,
// username and a "..." button. Same signals as EntryListItem.
Item {
    id: item
    property string uuid
    property string title
    property string username
    property string category
    property bool showDivider: true
    property int order: 0          // position in the list, used to stagger the intro animation

    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid, string title, string username)

    height: units.gu(9)
    BitwardenColors { id: bwc }

    // Intro: each row fades in and slides up a little, staggered by position
    property real appear: 0
    opacity: appear
    transform: Translate { y: (1 - item.appear) * units.gu(2.5) }
    SequentialAnimation {
        id: introAnimation
        PauseAnimation { duration: Math.min(item.order, 12) * 35 }
        NumberAnimation { target: item; property: "appear"; to: 1; duration: 320; easing.type: Easing.OutCubic }
    }
    Component.onCompleted: introAnimation.start()

    readonly property var avatarColors: ["#7c5cff", "#2f80ed", "#1fa971", "#e2803a", "#d9487d", "#00a3bf"]
    function colorFor(text) {
        var h = 0;
        for (var i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) & 0xffff;
        return avatarColors[h % avatarColors.length];
    }

    // Soft highlight while the row is pressed
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        opacity: rowArea.pressed ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        onClicked: item.entryClicked(item.uuid)
        onPressAndHold: item.entryLongPressed(item.uuid, item.title, item.username)
    }

    Rectangle {
        id: avatar
        anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
        width: units.gu(5); height: width
        radius: width / 2
        color: item.colorFor(item.title)
        Label {
            anchors.centerIn: parent
            text: item.title.length > 0 ? item.title.charAt(0).toUpperCase() : "?"
            color: "#ffffff"
            font.bold: true
            fontSize: "large"
        }
    }

    Column {
        anchors {
            left: avatar.right; leftMargin: units.gu(2)
            right: moreButton.left; rightMargin: units.gu(1)
            verticalCenter: parent.verticalCenter
        }
        spacing: units.gu(0.3)
        Label {
            width: parent.width
            text: item.title
            fontSize: "medium"
            color: bwc.text
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: item.username + (item.category ? "  \u00B7  " + item.category : "")
            fontSize: "small"
            color: bwc.secondaryText
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: moreButton
        anchors { right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
        width: units.gu(5); height: units.gu(6)
        onClicked: item.entryLongPressed(item.uuid, item.title, item.username)
        Icon {
            anchors.centerIn: parent
            scale: moreButton.pressed ? 0.8 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            width: units.gu(2.5); height: width
            name: "contextual-menu"
            color: bwc.secondaryText
        }
    }

    Rectangle {
        visible: item.showDivider
        anchors { left: parent.left; leftMargin: units.gu(9); right: parent.right; bottom: parent.bottom }
        height: units.dp(1)
        color: Qt.rgba(1, 1, 1, 0.07)
    }
}
