// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Home screen of the "Onyx" theme: round header buttons, big hero headline,
// pill search, security-check banner and the most recent entries.
Flickable {
    id: home
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property string userName: ""
    property string query: ""

    property int playCount: 0
    onVisibleChanged: if (visible) playCount++

    signal settingsRequested()
    signal lockRequested()
    signal securityRequested()
    signal seeAllRequested()
    signal queryEdited(string text)
    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid, string title, string username)
    signal copyRequested(string uuid)

    OnyxColors { id: c }

    contentWidth: width
    contentHeight: column.height + units.gu(14)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: parent.width
        spacing: units.gu(2.2)

        // ---- Header ----------------------------------------------------
        Item {
            width: parent.width
            height: units.gu(7)
            opacity: headAp.progress
            transform: Translate { y: -headAp.offset }
            Appear { id: headAp; run: home.playCount; distance: units.gu(3) }

            Rectangle {
                id: menuBtn
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(4.8); height: width; radius: width / 2
                color: menuArea.pressed ? c.cardPressed : c.pill
                border.width: units.dp(1); border.color: c.border
                scale: menuArea.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; width: units.gu(2.2); height: width; name: "settings"; color: c.text }
                MouseArea { id: menuArea; anchors.fill: parent; onClicked: home.settingsRequested() }
            }
            Row {
                anchors.centerIn: parent
                spacing: units.gu(1)
                Rectangle {
                    width: units.gu(3.2); height: width; radius: width / 2
                    color: c.text
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { anchors.centerIn: parent; width: units.gu(1.9); height: width; name: "lock"; color: c.accentText }
                }
                Label { text: i18n.tr("Vault"); font.bold: true; fontSize: "large"; color: c.text
                        anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                id: lockBtn
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(4.8); height: width; radius: width / 2
                color: lockArea.pressed ? c.cardPressed : c.pill
                border.width: units.dp(1); border.color: c.border
                scale: lockArea.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; width: units.gu(2.2); height: width; name: "lock"; color: c.text }
                MouseArea { id: lockArea; anchors.fill: parent; onClicked: home.lockRequested() }
            }
        }

        // ---- Hero ------------------------------------------------------
        Column {
            x: units.gu(2.5)
            width: parent.width - units.gu(5)
            spacing: units.gu(0.6)
            opacity: heroAp.progress
            scale: heroAp.zoom
            transformOrigin: Item.Left
            transform: Translate { y: heroAp.offset }
            Appear { id: heroAp; run: home.playCount; delay: 80; duration: 620
                     startScale: 0.94; distance: units.gu(3); easing: Easing.OutBack }
            Label {
                visible: home.userName.length > 0
                text: i18n.tr("Hi, %1").arg(home.userName)
                fontSize: "medium"; color: c.secondaryText
            }
            Label {
                width: parent.width
                text: i18n.tr("Keep\nYour Life\nSafe")
                font.bold: true
                font.pixelSize: units.gu(5.4)
                lineHeight: 0.92
                lineHeightMode: Text.ProportionalHeight
                color: c.text
            }
        }

        // ---- Search pill -----------------------------------------------
        Rectangle {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: units.gu(6.2)
            radius: height / 2
            color: c.pill
            border.width: searchInput.activeFocus ? units.dp(2) : units.dp(1)
            border.color: searchInput.activeFocus ? c.text : c.border
            Behavior on border.color { ColorAnimation { duration: 200 } }
            opacity: searchAp.progress
            transform: Translate { y: searchAp.offset }
            Appear { id: searchAp; run: home.playCount; delay: 180 }

            Icon {
                id: sIcon
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(2.3); height: width; name: "find"
                color: searchInput.activeFocus ? c.text : c.secondaryText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            TextInput {
                id: searchInput
                anchors { left: sIcon.right; leftMargin: units.gu(1.2); right: parent.right
                          rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                color: c.text; selectionColor: c.text; selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9); clip: true
                text: home.query
                onTextChanged: if (activeFocus) home.queryEdited(text)
                Label {
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Search")
                    fontSize: "small"; color: c.secondaryText
                }
            }
        }

        // ---- Security-check banner -------------------------------------
        Rectangle {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: units.gu(9.4)
            radius: units.gu(3)
            border.width: units.dp(1); border.color: c.border
            gradient: Gradient {
                GradientStop { position: 0; color: bannerArea.pressed ? c.cardPressed : c.cardTop }
                GradientStop { position: 1; color: bannerArea.pressed ? c.cardPressed : c.cardBottom }
            }
            opacity: banAp.progress
            scale: banAp.zoom * (bannerArea.pressed ? 0.98 : 1)
            Behavior on scale { NumberAnimation { duration: 140 } }
            transform: Translate { y: banAp.offset }
            Appear { id: banAp; run: home.playCount; delay: 260; startScale: 0.94; easing: Easing.OutBack }

            Item {
                id: banIcon
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: width
                // pulsing halo
                Rectangle {
                    id: halo
                    anchors.centerIn: parent
                    width: parent.width; height: width; radius: width / 2
                    color: "transparent"; border.width: units.dp(2); border.color: c.text
                    opacity: 0
                    SequentialAnimation {
                        running: home.visible
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: halo; property: "scale"; from: 1; to: 1.6; duration: 1800; easing.type: Easing.OutQuad }
                            SequentialAnimation {
                                NumberAnimation { target: halo; property: "opacity"; from: 0; to: 0.4; duration: 250 }
                                NumberAnimation { target: halo; property: "opacity"; to: 0; duration: 1550 }
                            }
                        }
                        PauseAnimation { duration: 700 }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: width / 2; color: c.tile
                    Icon { anchors.centerIn: parent; width: units.gu(2.6); height: width; name: "security-alert"; color: c.text }
                }
            }
            Column {
                anchors { left: banIcon.right; leftMargin: units.gu(1.8); right: banChev.left
                          rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                spacing: units.gu(0.5)
                Label { width: parent.width; text: i18n.tr("Run a security check"); font.bold: true
                        fontSize: "medium"; color: c.text; elide: Text.ElideRight }
                Label { width: parent.width; fontSize: "x-small"; color: c.secondaryText; elide: Text.ElideRight
                        text: home.overview.atRisk > 0
                              ? i18n.tr("%1 passwords need attention").arg(home.overview.atRisk)
                              : i18n.tr("Stay Safe. Stay Secure.") }
            }
            Icon {
                id: banChev
                anchors { right: parent.right; rightMargin: bannerArea.pressed ? units.gu(1) : units.gu(2); verticalCenter: parent.verticalCenter }
                Behavior on anchors.rightMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                width: units.gu(2.2); height: width; name: "go-next"; color: c.secondaryText
            }
            MouseArea { id: bannerArea; anchors.fill: parent; onClicked: home.securityRequested() }
        }

        // ---- Recent ----------------------------------------------------
        Item {
            x: units.gu(2.5)
            width: parent.width - units.gu(5)
            height: recTitle.height
            opacity: recAp.progress
            transform: Translate { x: -recAp.offset }
            Appear { id: recAp; run: home.playCount; delay: 360 }
            Label { id: recTitle; text: i18n.tr("Recent"); font.bold: true; fontSize: "medium"; color: c.text }
            Label {
                anchors.right: parent.right
                text: i18n.tr("See all")
                fontSize: "small"; color: c.secondaryText
                MouseArea { anchors.fill: parent; anchors.margins: -units.gu(1.5); onClicked: home.seeAllRequested() }
            }
        }

        Column {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            Label {
                visible: home.overview.recent.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: i18n.tr("No entries yet. Tap + to add one.")
                fontSize: "small"; color: c.secondaryText
            }
            Repeater {
                model: home.overview.recent
                delegate: OnyxEntryItem {
                    width: parent.width
                    order: index
                    run: home.playCount
                    uuid: modelData.uuid
                    title: modelData.title
                    subtitle: modelData.url || modelData.username
                    onEntryClicked: home.entryClicked(uuid)
                    onEntryLongPressed: home.entryLongPressed(uuid, modelData.title, modelData.username)
                    onCopyRequested: home.copyRequested(uuid)
                }
            }
        }
    }
}
