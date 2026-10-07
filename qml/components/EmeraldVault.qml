// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Whole vault layout of the "Emerald" theme:
//   Home  - greeting, search, Health Score, recent entries
//   Vault - category grid ("Organized by category"), tap one for its list
// plus a floating "+" button and a bottom bar (Home / Vault / Generator / Settings).
Item {
    id: ev
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property var entries: []
    property string userName: ""
    property string query: ""

    property int tab: 0                 // 0 = home, 1 = vault (categories)
    property bool showAll: false
    property string categoryFilter: ""
    readonly property bool listMode: query.length > 0 || showAll || categoryFilter !== ""
    readonly property int navTab: (tab === 1 || listMode) ? 1 : 0
    readonly property bool homeVisible: !listMode && tab === 0
    readonly property bool gridVisible: !listMode && tab === 1

    signal addRequested()
    signal generatorRequested()
    signal settingsRequested()
    signal lockRequested()
    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid, string title, string username)

    EmeraldColors { id: c }

    function resetTo(newTab) {
        tab = newTab;
        showAll = false;
        categoryFilter = "";
        query = "";
    }

    // The home search box is hidden once typing starts (list mode), so move the
    // keyboard focus to the list pane's own search box.
    onListModeChanged: if (listMode && query.length > 0) focusTimer.restart()
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: {
            listSearch.forceActiveFocus();
            listSearch.cursorPosition = listSearch.text.length;
        }
    }

    // ---- Home ----------------------------------------------------------
    EmeraldHome {
        id: homePane
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        opacity: ev.homeVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        overview: ev.overview
        userName: ev.userName
        query: ev.query
        onQueryEdited: ev.query = text
        onLockRequested: ev.lockRequested()
        onSeeAllRequested: { ev.tab = 0; ev.showAll = true; }
        onEntryClicked: ev.entryClicked(uuid)
        onEntryLongPressed: ev.entryLongPressed(uuid, title, username)
    }

    // ---- Vault: category grid -----------------------------------------
    Flickable {
        id: gridPane
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        opacity: ev.gridVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        contentWidth: width
        contentHeight: gridColumn.height + units.gu(14)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        property int playCount: 0
        onVisibleChanged: if (visible) playCount++

        Column {
            id: gridColumn
            width: parent.width
            spacing: units.gu(2)

            Item { width: 1; height: units.gu(0.2) }

            Column {
                x: units.gu(2.5)
                width: parent.width - units.gu(5)
                spacing: units.gu(0.4)
                opacity: gTitleAp.progress
                transform: Translate { x: -gTitleAp.offset }
                Appear { id: gTitleAp; run: gridPane.playCount }
                Label { text: i18n.tr("Vault"); font.bold: true; fontSize: "x-large"; color: c.text }
                Label { text: i18n.tr("Organized by category"); fontSize: "small"; color: c.secondaryText }
            }

            Flow {
                x: units.gu(2)
                width: parent.width - units.gu(4)
                spacing: units.gu(1.2)

                Repeater {
                    // first card = every entry, then one card per category
                    model: [{ name: "", label: i18n.tr("All items"), count: ev.overview.total }]
                           .concat(ev.overview.categories.map(function (cat) {
                               return { name: cat.name, label: cat.name, count: cat.count };
                           }))
                    delegate: Rectangle {
                        id: catCard
                        width: (parent.width - units.gu(1.2)) / 2
                        height: units.gu(13.5)
                        radius: units.gu(1.8)
                        color: catArea.pressed ? c.cardPressed : c.card
                        border.width: units.dp(1)
                        border.color: catArea.pressed ? c.accent : c.border
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        property real pressScale: catArea.pressed ? 0.96 : 1
                        Behavior on pressScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        opacity: catAp.progress
                        scale: pressScale * catAp.zoom
                        transform: Translate { y: catAp.offset }
                        Appear { id: catAp; run: gridPane.playCount; delay: 80 + Math.min(index, 9) * 55
                                 startScale: 0.88; easing: Easing.OutBack }

                        Rectangle {
                            id: catTile
                            anchors { left: parent.left; top: parent.top; margins: units.gu(1.8) }
                            width: units.gu(4.6); height: width; radius: units.gu(1.3)
                            color: c.tile
                            Label {
                                anchors.centerIn: parent
                                text: modelData.name === "" ? "\u2605" : modelData.label.charAt(0).toUpperCase()
                                font.bold: true; fontSize: "large"; color: c.accent
                            }
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: units.gu(1.8) }
                            spacing: units.gu(0.3)
                            Label { width: parent.width; text: modelData.label; fontSize: "medium"
                                    font.bold: true; color: c.text; elide: Text.ElideRight }
                            Label { width: parent.width; fontSize: "x-small"; color: c.secondaryText
                                    text: modelData.count === 1 ? i18n.tr("1 item") : i18n.tr("%1 items").arg(modelData.count) }
                        }
                        MouseArea {
                            id: catArea
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.name === "") { ev.showAll = true; ev.categoryFilter = ""; }
                                else ev.categoryFilter = modelData.name;
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- List: all entries / one category / search results -------------
    Item {
        id: listPane
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        opacity: ev.listMode ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        transform: Translate { y: (1 - listPane.opacity) * units.gu(2.5) }

        Rectangle {
            id: listSearchBox
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(1) }
            height: units.gu(6); radius: units.gu(1.8)
            color: c.field
            border.width: listSearch.activeFocus ? units.dp(2) : units.dp(1)
            border.color: listSearch.activeFocus ? c.accent : c.border
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Icon {
                id: lIcon
                anchors { left: parent.left; leftMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
                width: units.gu(2.3); height: width; name: "find"
                color: listSearch.activeFocus ? c.accent : c.secondaryText
            }
            TextInput {
                id: listSearch
                anchors { left: lIcon.right; leftMargin: units.gu(1); right: parent.right
                          rightMargin: units.gu(1.2); verticalCenter: parent.verticalCenter }
                color: c.text; selectionColor: c.accent; selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9); clip: true
                text: ev.query
                onTextChanged: if (activeFocus) ev.query = text
                Label {
                    visible: listSearch.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Search your vault...")
                    fontSize: "small"; color: c.secondaryText
                }
            }
        }
        Label {
            id: listTitle
            anchors { left: parent.left; leftMargin: units.gu(2.5); top: listSearchBox.bottom; topMargin: units.gu(1.8) }
            text: (ev.categoryFilter !== "" ? ev.categoryFilter : i18n.tr("All items")) + " (" + entryList.count + ")"
            font.bold: true; fontSize: "medium"; color: c.text
        }
        Label {
            anchors { right: parent.right; rightMargin: units.gu(2.5); verticalCenter: listTitle.verticalCenter }
            text: i18n.tr("BACK")
            font.bold: true; fontSize: "x-small"; font.letterSpacing: units.dp(1.2)
            color: c.accent
            MouseArea {
                anchors.fill: parent; anchors.margins: -units.gu(1.5)
                onClicked: { ev.showAll = false; ev.categoryFilter = ""; ev.query = ""; }
            }
        }
        ListView {
            id: entryList
            anchors { left: parent.left; right: parent.right; top: listTitle.bottom; bottom: parent.bottom
                      leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(0.8) }
            clip: true
            model: ev.categoryFilter === "" ? ev.entries
                   : ev.entries.filter(function (e) { return e.category === ev.categoryFilter; })
            footer: Item { width: 1; height: units.gu(14) }
            delegate: EmeraldEntryItem {
                width: ListView.view ? ListView.view.width : 0
                order: index
                run: ev.listMode ? 1 : 0
                uuid: modelData.uuid
                title: modelData.title
                subtitle: modelData.username
                onEntryClicked: ev.entryClicked(uuid)
                onEntryLongPressed: ev.entryLongPressed(uuid, modelData.title, modelData.username)
            }
        }
    }

    // ---- Floating "+" button ------------------------------------------
    Rectangle {
        id: fab
        z: 6
        anchors { right: parent.right; rightMargin: units.gu(2.2); bottom: nav.top; bottomMargin: units.gu(2) }
        width: units.gu(6.6); height: width; radius: units.gu(2)
        color: c.accent
        scale: fabArea.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        opacity: navAp.progress
        // soft halo
        Rectangle {
            z: -1
            anchors { fill: parent; margins: -units.dp(5) }
            radius: parent.radius + units.dp(5)
            color: c.accent
            opacity: 0.18
        }
        Icon {
            anchors.centerIn: parent
            width: units.gu(3); height: width; name: "add"; color: c.accentText
            rotation: fabArea.pressed ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        }
        MouseArea { id: fabArea; anchors.fill: parent; onClicked: ev.addRequested() }
    }

    // ---- Bottom navigation --------------------------------------------
    Rectangle {
        id: nav
        z: 5
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.gu(8)
        color: c.nav
        opacity: navAp.progress
        transform: Translate { y: navAp.offset }
        Appear { id: navAp; delay: 200; distance: units.gu(8); duration: 520 }

        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: units.dp(1); color: c.border }

        // glowing indicator that glides between the tabs
        Rectangle {
            y: 0
            width: nav.width / 4 * 0.4; height: units.dp(3); radius: height / 2
            color: c.accent
            x: ev.navTab * nav.width / 4 + nav.width / 4 * 0.3
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
        }

        Repeater {
            model: [
                { label: i18n.tr("HOME"),     icon: "home",     tab: 0 },
                { label: i18n.tr("VAULT"),    icon: "lock",     tab: 1 },
                { label: i18n.tr("GENERATOR"), icon: "reload",  tab: 2 },
                { label: i18n.tr("SETTINGS"), icon: "settings", tab: 3 }
            ]
            delegate: Item {
                id: navItem
                x: index * nav.width / 4
                width: nav.width / 4
                height: nav.height
                property bool current: modelData.tab === ev.navTab
                Column {
                    anchors.centerIn: parent
                    spacing: units.gu(0.5)
                    property real pressScale: navArea.pressed ? 0.85 : 1
                    Behavior on pressScale { NumberAnimation { duration: 120 } }
                    scale: (navItem.current ? 1.1 : 1) * pressScale
                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(2.8); height: width
                        name: modelData.icon
                        color: navItem.current ? c.accent : c.secondaryText
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.bold: true; fontSize: "x-small"; font.letterSpacing: units.dp(0.8)
                        color: navItem.current ? c.accent : c.secondaryText
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
                MouseArea {
                    id: navArea
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.tab === 0) ev.resetTo(0);
                        else if (modelData.tab === 1) ev.resetTo(1);
                        else if (modelData.tab === 2) ev.generatorRequested();
                        else ev.settingsRequested();
                    }
                }
            }
        }
    }
}
