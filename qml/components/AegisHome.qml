// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Home screen of the "Aegis" theme: greeting, counters, categories and the
// most recently changed entries. Data comes from vault_backend.get_overview().
Flickable {
    id: home
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property string userName: ""
    property alias query: searchInput.text

    signal addRequested()
    signal entryClicked(string uuid)
    signal categoryClicked(string name)

    AegisColors { id: c }

    contentWidth: width
    contentHeight: column.height + units.gu(12)   // clear of the bottom bar
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function tileColor(text) {
        var h = 0;
        for (var i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) & 0xffff;
        return c.tileColors[h % c.tileColors.length];
    }
    function ago(ts) {
        if (!ts) return "";
        var s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
        if (s < 60) return i18n.tr("just now");
        var m = Math.floor(s / 60);
        if (m < 60) return i18n.tr("%1 min ago").arg(m);
        var h = Math.floor(m / 60);
        if (h < 24) return i18n.tr("%1 h ago").arg(h);
        var d = Math.floor(h / 24);
        return d === 1 ? i18n.tr("1 day ago") : i18n.tr("%1 days ago").arg(d);
    }

    Column {
        id: column
        width: parent.width
        spacing: units.gu(2.5)

        // ---- Hero: greeting + shield ---------------------------------
        Item {
            width: parent.width
            height: units.gu(15)

            Column {
                anchors { left: parent.left; leftMargin: units.gu(2); right: shield.left; verticalCenter: parent.verticalCenter }
                spacing: units.gu(0.8)
                Label {
                    width: parent.width
                    text: home.userName ? i18n.tr("Hello, %1!").arg(home.userName) : i18n.tr("Hello!")
                    font.bold: true
                    fontSize: "x-large"
                    color: c.text
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: i18n.tr("Your passwords, safe and always with you.")
                    fontSize: "small"
                    color: c.secondaryText
                    wrapMode: Text.WordWrap
                }
            }

            // Glowing shield
            Item {
                id: shield
                width: units.gu(13); height: width
                anchors { right: parent.right; rightMargin: units.gu(1.5); verticalCenter: parent.verticalCenter }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.9; height: width; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#3b2f9e" }
                        GradientStop { position: 1; color: "#241a5c" }
                    }
                    opacity: 0.55
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.55; height: width * 1.1; radius: units.gu(2.2)
                    gradient: Gradient {
                        GradientStop { position: 0; color: c.accentSoft }
                        GradientStop { position: 1; color: c.accent }
                    }
                    Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.5; height: width
                        name: "lock"
                        color: "#ffffff"
                    }
                }
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.04; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 2200; easing.type: Easing.InOutSine }
                }
            }
        }

        // ---- Counters -------------------------------------------------
        Row {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: units.gu(1)
            Repeater {
                model: [
                    { label: i18n.tr("All passwords"), value: home.overview.total,   col: c.accentSoft, icon: "lock" },
                    { label: i18n.tr("Secure"),        value: home.overview.secure,  col: c.good,       icon: "tick" },
                    { label: i18n.tr("At risk"),       value: home.overview.atRisk,  col: c.warn,       icon: "security-alert" },
                    { label: i18n.tr("Categories"),    value: home.overview.categories.length, col: c.folder, icon: "folder-symbolic" }
                ]
                delegate: Rectangle {
                    width: (parent.width - 3 * units.gu(1)) / 4
                    height: units.gu(11)
                    radius: units.gu(1.5)
                    color: c.card
                    border.width: units.dp(1); border.color: c.border
                    Column {
                        anchors { fill: parent; margins: units.gu(1) }
                        spacing: units.gu(0.6)
                        Icon { width: units.gu(2.6); height: width; name: modelData.icon; color: modelData.col }
                        Label { width: parent.width; text: modelData.label; fontSize: "x-small"; color: c.secondaryText; elide: Text.ElideRight }
                        Label { text: modelData.value; fontSize: "x-large"; font.bold: true; color: c.text }
                    }
                }
            }
        }

        // ---- Search + new password ------------------------------------
        Row {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: units.gu(1)

            Rectangle {
                width: parent.width - addBtn.width - units.gu(1)
                height: units.gu(6)
                radius: units.gu(1.2)
                color: c.field
                border.width: searchInput.activeFocus ? units.dp(2) : units.dp(1)
                border.color: searchInput.activeFocus ? c.accent : c.border
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Icon {
                    id: sIcon
                    anchors { left: parent.left; leftMargin: units.gu(1.5); verticalCenter: parent.verticalCenter }
                    width: units.gu(2.4); height: width; name: "find"; color: c.secondaryText
                }
                TextInput {
                    id: searchInput
                    anchors { left: sIcon.right; leftMargin: units.gu(1); right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                    color: c.text
                    selectionColor: c.accent
                    font.pixelSize: units.gu(1.9)
                    clip: true
                    Label {
                        visible: searchInput.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18n.tr("Search passwords...")
                        fontSize: "small"
                        color: c.secondaryText
                    }
                }
            }

            Rectangle {
                id: addBtn
                width: units.gu(15); height: units.gu(6)
                radius: units.gu(1.2)
                gradient: Gradient {
                    GradientStop { position: 0; color: c.accentSoft }
                    GradientStop { position: 1; color: c.accent }
                }
                scale: addArea.pressed ? 0.95 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Row {
                    anchors.centerIn: parent
                    spacing: units.gu(0.6)
                    Icon { width: units.gu(2.2); height: width; name: "add"; color: "#fff"; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: i18n.tr("New"); font.bold: true; color: "#fff"; fontSize: "small"; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: addArea; anchors.fill: parent; onClicked: home.addRequested() }
            }
        }

        // ---- Categories -----------------------------------------------
        Item {
            width: parent.width
            height: catTitle.height
            Label { id: catTitle; x: units.gu(2); text: i18n.tr("Categories"); font.bold: true; fontSize: "medium"; color: c.text }
        }
        Flow {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: units.gu(1)
            Repeater {
                model: home.overview.categories
                delegate: Rectangle {
                    width: (parent.width - 3 * units.gu(1)) / 4
                    height: units.gu(11)
                    radius: units.gu(1.5)
                    color: c.card
                    border.width: units.dp(1); border.color: c.border
                    scale: catArea.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - units.gu(1)
                        spacing: units.gu(0.6)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: units.gu(4.2); height: width; radius: units.gu(1.1)
                            color: Qt.rgba(Qt.color(home.tileColor(modelData.name)).r,
                                           Qt.color(home.tileColor(modelData.name)).g,
                                           Qt.color(home.tileColor(modelData.name)).b, 0.22)
                            Label {
                                anchors.centerIn: parent
                                text: modelData.name.charAt(0).toUpperCase()
                                font.bold: true; fontSize: "large"
                                color: home.tileColor(modelData.name)
                            }
                        }
                        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.name; fontSize: "x-small"; color: c.text; elide: Text.ElideRight }
                        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.count; fontSize: "x-small"; color: c.secondaryText }
                    }
                    MouseArea { id: catArea; anchors.fill: parent; onClicked: home.categoryClicked(modelData.name) }
                }
            }
        }

        // ---- Recent ---------------------------------------------------
        Item {
            width: parent.width
            height: recTitle.height
            Label { id: recTitle; x: units.gu(2); text: i18n.tr("Recent passwords"); font.bold: true; fontSize: "medium"; color: c.text }
        }
        Rectangle {
            x: units.gu(2)
            width: parent.width - units.gu(4)
            height: recentCol.height
            radius: units.gu(1.5)
            color: c.card
            border.width: units.dp(1); border.color: c.border
            clip: true
            Column {
                id: recentCol
                width: parent.width
                Repeater {
                    model: home.overview.recent
                    delegate: Item {
                        width: recentCol.width
                        height: units.gu(8)
                        Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: rowArea.pressed ? 0.06 : 0 }
                        Rectangle {
                            id: tile
                            anchors { left: parent.left; leftMargin: units.gu(1.5); verticalCenter: parent.verticalCenter }
                            width: units.gu(5); height: width; radius: width / 2
                            color: home.tileColor(modelData.title)
                            Label { anchors.centerIn: parent; text: modelData.title.charAt(0).toUpperCase(); font.bold: true; fontSize: "large"; color: "#fff" }
                        }
                        Column {
                            anchors { left: tile.right; leftMargin: units.gu(1.5); right: when.left; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                            spacing: units.gu(0.3)
                            Label { width: parent.width; text: modelData.title; fontSize: "medium"; color: c.text; elide: Text.ElideRight }
                            Label { width: parent.width; text: modelData.url || modelData.username; fontSize: "x-small"; color: c.secondaryText; elide: Text.ElideRight }
                        }
                        Label {
                            id: when
                            anchors { right: chev.left; rightMargin: units.gu(0.5); verticalCenter: parent.verticalCenter }
                            text: home.ago(modelData.modified)
                            fontSize: "x-small"; color: c.secondaryText
                        }
                        Icon { id: chev; anchors { right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                               width: units.gu(2); height: width; name: "go-next"; color: c.secondaryText }
                        Rectangle {
                            visible: index < home.overview.recent.length - 1
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: units.dp(1); color: c.border
                        }
                        MouseArea { id: rowArea; anchors.fill: parent; onClicked: home.entryClicked(modelData.uuid) }
                    }
                }
            }
        }
    }
}
