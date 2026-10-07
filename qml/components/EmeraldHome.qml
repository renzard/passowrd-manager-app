// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Home screen of the "Emerald" theme: greeting header, search, Health Score
// ring and the most recent entries. Data comes from vault_backend.get_overview().
Flickable {
    id: home
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property string userName: ""
    property string query: ""

    // Incremented whenever the screen becomes visible so the intro replays.
    property int playCount: 0
    onVisibleChanged: if (visible) playCount++

    signal lockRequested()
    signal seeAllRequested()
    signal queryEdited(string text)
    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid, string title, string username)

    EmeraldColors { id: c }

    contentWidth: width
    contentHeight: column.height + units.gu(14)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function greeting() {
        var h = new Date().getHours();
        if (h < 12) return i18n.tr("GOOD MORNING");
        if (h < 18) return i18n.tr("GOOD AFTERNOON");
        return i18n.tr("GOOD EVENING");
    }

    Column {
        id: column
        width: parent.width
        spacing: units.gu(2.4)

        // ---- Header: avatar + greeting + lock --------------------------
        Item {
            width: parent.width
            height: units.gu(8)
            opacity: headAp.progress
            transform: Translate { y: -headAp.offset }
            Appear { id: headAp; run: home.playCount; distance: units.gu(3) }

            Rectangle {
                id: avatar
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(5.4); height: width; radius: width / 2
                color: c.tile
                border.width: units.dp(2); border.color: c.accent
                Label {
                    anchors.centerIn: parent
                    text: home.userName.length ? home.userName.charAt(0).toUpperCase() : "\u2022"
                    font.bold: true; fontSize: "large"; color: c.accent
                }
            }
            Column {
                anchors { left: avatar.right; leftMargin: units.gu(1.5); right: lockBtn.left
                          rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                spacing: units.gu(0.3)
                Label {
                    width: parent.width
                    text: { home.playCount; return home.greeting(); }
                    font.bold: true; fontSize: "x-small"; font.letterSpacing: units.dp(1.5)
                    color: c.secondaryText
                }
                Label {
                    width: parent.width
                    text: home.userName.length ? home.userName : i18n.tr("Welcome")
                    font.bold: true; fontSize: "large"; color: c.text
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                id: lockBtn
                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(4.6); height: width; radius: width / 2
                color: lockArea.pressed ? c.cardPressed : c.card
                border.width: units.dp(1); border.color: c.border
                scale: lockArea.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Icon { anchors.centerIn: parent; width: units.gu(2.2); height: width; name: "lock"; color: c.secondaryText }
                MouseArea { id: lockArea; anchors.fill: parent; onClicked: home.lockRequested() }
            }
        }

        // ---- Search ----------------------------------------------------
        Rectangle {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: units.gu(6)
            radius: units.gu(1.8)
            color: c.field
            border.width: searchInput.activeFocus ? units.dp(2) : units.dp(1)
            border.color: searchInput.activeFocus ? c.accent : c.border
            Behavior on border.color { ColorAnimation { duration: 200 } }
            opacity: searchAp.progress
            transform: Translate { y: searchAp.offset }
            Appear { id: searchAp; run: home.playCount; delay: 100 }

            Icon {
                id: sIcon
                anchors { left: parent.left; leftMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
                width: units.gu(2.3); height: width; name: "find"
                color: searchInput.activeFocus ? c.accent : c.secondaryText
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            TextInput {
                id: searchInput
                anchors { left: sIcon.right; leftMargin: units.gu(1); right: parent.right
                          rightMargin: units.gu(1.2); verticalCenter: parent.verticalCenter }
                color: c.text; selectionColor: c.accent; selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9); clip: true
                text: home.query
                onTextChanged: if (activeFocus) home.queryEdited(text)
                Label {
                    visible: searchInput.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Search your vault...")
                    fontSize: "small"; color: c.secondaryText
                }
            }
        }

        // ---- Health score ---------------------------------------------
        Rectangle {
            id: healthCard
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: units.gu(14)
            radius: units.gu(2)
            color: c.card
            border.width: units.dp(1); border.color: c.border
            opacity: healthAp.progress
            scale: healthAp.zoom
            transform: Translate { y: healthAp.offset }
            Appear { id: healthAp; run: home.playCount; delay: 200; startScale: 0.94; easing: Easing.OutBack }

            // soft green glow in the corner
            Rectangle {
                anchors { right: parent.right; top: parent.top; margins: units.gu(1.5) }
                width: units.gu(7); height: width; radius: width / 2
                color: c.accentSoft
                opacity: 0.6
                SequentialAnimation on opacity {
                    running: home.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.4; duration: 1800; easing.type: Easing.InOutSine }
                }
            }

            Item {
                id: ring
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(9); height: width
                property real shown: 0
                property real target: home.overview.total > 0 ? home.overview.secure / home.overview.total : 1

                SequentialAnimation {
                    id: ringAnim
                    PauseAnimation { duration: 350 }
                    NumberAnimation { target: ring; property: "shown"; from: 0; to: ring.target
                                      duration: 1000; easing.type: Easing.OutCubic }
                }
                Connections { target: home; onPlayCountChanged: ringAnim.restart() }
                onTargetChanged: ringAnim.restart()
                Component.onCompleted: ringAnim.start()
                onShownChanged: canvas.requestPaint()

                Canvas {
                    id: canvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var lw = units.dp(5);
                        var r = width / 2 - lw;
                        var cx = width / 2, cy = height / 2;
                        ctx.lineWidth = lw;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = String(c.track);
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.stroke();
                        if (ring.shown > 0.001) {
                            ctx.strokeStyle = String(c.accent);
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * ring.shown);
                            ctx.stroke();
                        }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    text: Math.round(ring.shown * 100) + "%"
                    font.bold: true; fontSize: "medium"; color: c.text
                }
            }

            Column {
                anchors { left: ring.right; leftMargin: units.gu(2); right: parent.right
                          rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                spacing: units.gu(0.6)
                Label { text: i18n.tr("Health Score"); font.bold: true; fontSize: "large"; color: c.text }
                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    fontSize: "small"; color: c.secondaryText
                    text: home.overview.total === 0
                          ? i18n.tr("Add your first password to get started.")
                          : (home.overview.atRisk === 0
                             ? i18n.tr("Your vault is in great shape.")
                             : i18n.tr("Your vault is in good shape. %1 passwords need update.").arg(home.overview.atRisk))
                }
            }
        }

        // ---- Recent entries -------------------------------------------
        Item {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: recTitle.height
            opacity: recAp.progress
            transform: Translate { x: -recAp.offset }
            Appear { id: recAp; run: home.playCount; delay: 320 }
            Label {
                id: recTitle
                text: i18n.tr("RECENT ENTRIES")
                font.bold: true; fontSize: "x-small"; font.letterSpacing: units.dp(1.5)
                color: c.secondaryText
            }
            Label {
                anchors.right: parent.right
                text: i18n.tr("SEE ALL")
                font.bold: true; fontSize: "x-small"; font.letterSpacing: units.dp(1.2)
                color: c.accent
                MouseArea { anchors.fill: parent; anchors.margins: -units.gu(1.5); onClicked: home.seeAllRequested() }
            }
        }

        Column {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: 0
            Label {
                visible: home.overview.recent.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: i18n.tr("No entries yet. Tap + to add one.")
                fontSize: "small"; color: c.secondaryText
            }
            Repeater {
                model: home.overview.recent
                delegate: EmeraldEntryItem {
                    width: parent.width
                    order: index
                    run: home.playCount
                    uuid: modelData.uuid
                    title: modelData.title
                    subtitle: modelData.url || modelData.username
                    onEntryClicked: home.entryClicked(uuid)
                    onEntryLongPressed: home.entryLongPressed(uuid, modelData.title, modelData.username)
                }
            }
        }
    }
}
