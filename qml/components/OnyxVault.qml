// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Whole vault layout of the "Onyx" theme:
//   Home     - hero headline, search, security banner, recent entries
//   Security - password health bar + overview rows
//   List     - all entries / one category / search results (category chips)
// plus a floating pill bar: Home / Security / Generator / Settings / +
Item {
    id: ov
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property var entries: []
    property string userName: ""
    property string query: ""

    property int tab: 0                 // 0 = home, 1 = security
    property bool showAll: false
    property string categoryFilter: ""
    readonly property bool listMode: query.length > 0 || showAll || categoryFilter !== ""
    readonly property int navTab: tab
    readonly property bool homeVisible: !listMode && tab === 0
    readonly property bool securityVisible: !listMode && tab === 1

    signal addRequested()
    signal generatorRequested()
    signal settingsRequested()
    signal lockRequested()
    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid, string title, string username)
    signal copyRequested(string uuid)

    OnyxColors { id: c }

    function resetTo(newTab) {
        tab = newTab;
        showAll = false;
        categoryFilter = "";
        query = "";
    }

    // Home's search box hides once typing starts; hand the focus to the list's.
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
    OnyxHome {
        anchors.fill: parent
        opacity: ov.homeVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        overview: ov.overview
        userName: ov.userName
        query: ov.query
        onQueryEdited: ov.query = text
        onSettingsRequested: ov.settingsRequested()
        onLockRequested: ov.lockRequested()
        onSecurityRequested: ov.tab = 1
        onSeeAllRequested: { ov.tab = 0; ov.showAll = true; }
        onEntryClicked: ov.entryClicked(uuid)
        onEntryLongPressed: ov.entryLongPressed(uuid, title, username)
        onCopyRequested: ov.copyRequested(uuid)
    }

    // ---- Security ------------------------------------------------------
    Flickable {
        id: secPane
        anchors.fill: parent
        opacity: ov.securityVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        contentWidth: width
        contentHeight: secColumn.height + units.gu(14)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        property int playCount: 0
        onVisibleChanged: if (visible) playCount++

        Column {
            id: secColumn
            width: parent.width
            spacing: units.gu(2)

            Item { width: 1; height: units.gu(0.2) }

            Column {
                x: units.gu(2.5)
                width: parent.width - units.gu(5)
                spacing: units.gu(0.4)
                opacity: secTitleAp.progress
                transform: Translate { x: -secTitleAp.offset }
                Appear { id: secTitleAp; run: secPane.playCount }
                Label { text: i18n.tr("Security"); font.bold: true; fontSize: "x-large"; color: c.text }
                Label { text: i18n.tr("Keep your passwords healthy"); fontSize: "small"; color: c.secondaryText }
            }

            // Health card with an animated bar
            Rectangle {
                x: units.gu(2)
                width: parent.width - units.gu(4)
                height: units.gu(13)
                radius: units.gu(3)
                border.width: units.dp(1); border.color: c.border
                gradient: Gradient {
                    GradientStop { position: 0; color: c.cardTop }
                    GradientStop { position: 1; color: c.cardBottom }
                }
                opacity: healthAp.progress
                scale: healthAp.zoom
                transform: Translate { y: healthAp.offset }
                Appear { id: healthAp; run: secPane.playCount; delay: 100; startScale: 0.94; easing: Easing.OutBack }

                property real target: ov.overview.total > 0 ? ov.overview.secure / ov.overview.total : 1
                property real shown: 0
                SequentialAnimation {
                    id: barAnim
                    PauseAnimation { duration: 300 }
                    NumberAnimation { target: healthCardRef; property: "shown"; from: 0; to: healthCardRef.target
                                      duration: 1000; easing.type: Easing.OutCubic }
                }
                id: healthCardRef
                Connections { target: secPane; onPlayCountChanged: barAnim.restart() }
                onTargetChanged: barAnim.restart()
                Component.onCompleted: barAnim.start()

                Label {
                    anchors { left: parent.left; top: parent.top; leftMargin: units.gu(2.2); topMargin: units.gu(2) }
                    text: i18n.tr("Password health")
                    fontSize: "small"; color: c.secondaryText
                }
                Label {
                    anchors { right: parent.right; top: parent.top; rightMargin: units.gu(2.2); topMargin: units.gu(1.6) }
                    text: Math.round(healthCardRef.shown * 100) + "%"
                    font.bold: true; fontSize: "large"; color: c.text
                }
                Rectangle {
                    id: track
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: units.gu(2.2); rightMargin: units.gu(2.2); verticalCenterOffset: units.gu(0.8) }
                    height: units.gu(2.2); radius: height / 2
                    color: c.track
                    Rectangle {
                        width: Math.max(parent.height, parent.width * healthCardRef.shown)
                        height: parent.height; radius: height / 2
                        color: c.text
                    }
                }
                Label {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: units.gu(2.2); bottomMargin: units.gu(1.6) }
                    fontSize: "x-small"; color: c.secondaryText
                    text: ov.overview.total === 0 ? i18n.tr("No passwords yet")
                          : i18n.tr("%1 of %2 passwords are secure").arg(ov.overview.secure).arg(ov.overview.total)
                }
            }

            // Overview rows
            Column {
                x: units.gu(2)
                width: parent.width - units.gu(4)
                Repeater {
                    model: [
                        { title: i18n.tr("All passwords"),   sub: i18n.tr("Browse every entry"),
                          icon: "lock",           count: ov.overview.total,             go: true },
                        { title: i18n.tr("Secure"),          sub: i18n.tr("No weak or reused password"),
                          icon: "tick",           count: ov.overview.secure,            go: false },
                        { title: i18n.tr("Need attention"),  sub: i18n.tr("Weak or reused passwords"),
                          icon: "security-alert", count: ov.overview.atRisk,            go: false },
                        { title: i18n.tr("Categories"),      sub: i18n.tr("Browse by category"),
                          icon: "folder-symbolic", count: ov.overview.categories.length, go: true }
                    ]
                    delegate: Item {
                        id: row
                        width: parent.width
                        height: units.gu(9)
                        opacity: rowAp.progress
                        transform: Translate { x: rowAp.offset }
                        Appear { id: rowAp; run: secPane.playCount; delay: 200 + index * 80
                                 distance: units.gu(3); duration: 420 }
                        Rectangle {
                            anchors { fill: parent; topMargin: units.gu(0.6); bottomMargin: units.gu(0.6) }
                            radius: units.gu(2.4)
                            border.width: units.dp(1); border.color: c.border
                            gradient: Gradient {
                                GradientStop { position: 0; color: (rowArea.pressed && modelData.go) ? c.cardPressed : c.cardTop }
                                GradientStop { position: 1; color: (rowArea.pressed && modelData.go) ? c.cardPressed : c.cardBottom }
                            }
                            Rectangle {
                                id: rIcon
                                anchors { left: parent.left; leftMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
                                width: units.gu(5); height: width; radius: width / 2
                                color: c.tile
                                Icon { anchors.centerIn: parent; width: units.gu(2.4); height: width
                                       name: modelData.icon; color: c.text }
                            }
                            Column {
                                anchors { left: rIcon.right; leftMargin: units.gu(1.6); right: rCount.left
                                          rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                                spacing: units.gu(0.4)
                                Label { width: parent.width; text: modelData.title; font.bold: true
                                        fontSize: "medium"; color: c.text; elide: Text.ElideRight }
                                Label { width: parent.width; text: modelData.sub; fontSize: "x-small"
                                        color: c.secondaryText; elide: Text.ElideRight }
                            }
                            Label {
                                id: rCount
                                anchors { right: rChev.left; rightMargin: units.gu(0.8); verticalCenter: parent.verticalCenter }
                                text: modelData.count
                                font.bold: true; fontSize: "large"; color: c.text
                            }
                            Icon {
                                id: rChev
                                anchors { right: parent.right; rightMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
                                width: units.gu(2); height: width; name: "go-next"
                                color: c.secondaryText
                                opacity: modelData.go ? 1 : 0
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            enabled: modelData.go
                            onClicked: { ov.tab = 0; ov.showAll = true; ov.categoryFilter = ""; }
                        }
                    }
                }
            }
        }
    }

    // ---- List: all entries / one category / search results -------------
    Item {
        id: listPane
        anchors.fill: parent
        opacity: ov.listMode ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        transform: Translate { y: (1 - listPane.opacity) * units.gu(2.5) }

        Rectangle {
            id: listSearchBox
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(1) }
            height: units.gu(6.2); radius: height / 2
            color: c.pill
            border.width: listSearch.activeFocus ? units.dp(2) : units.dp(1)
            border.color: listSearch.activeFocus ? c.text : c.border
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Icon {
                id: lIcon
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(2.3); height: width; name: "find"
                color: listSearch.activeFocus ? c.text : c.secondaryText
            }
            TextInput {
                id: listSearch
                anchors { left: lIcon.right; leftMargin: units.gu(1.2); right: parent.right
                          rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                color: c.text; selectionColor: c.text; selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9); clip: true
                text: ov.query
                onTextChanged: if (activeFocus) ov.query = text
                Label {
                    visible: listSearch.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Search")
                    fontSize: "small"; color: c.secondaryText
                }
            }
        }

        // Category chips
        ListView {
            id: chips
            anchors { left: parent.left; right: parent.right; top: listSearchBox.bottom; topMargin: units.gu(1.4) }
            height: units.gu(4.6)
            orientation: ListView.Horizontal
            spacing: units.gu(1)
            leftMargin: units.gu(2); rightMargin: units.gu(2)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: [{ name: "", label: i18n.tr("All") }]
                   .concat(ov.overview.categories.map(function (cat) { return { name: cat.name, label: cat.name }; }))
            delegate: Rectangle {
                property bool current: ov.categoryFilter === modelData.name
                height: chips.height
                width: chipLabel.width + units.gu(3.2)
                radius: height / 2
                color: current ? c.text : c.pill
                border.width: units.dp(1); border.color: current ? c.text : c.border
                Behavior on color { ColorAnimation { duration: 200 } }
                scale: chipArea.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Label {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    fontSize: "small"; font.bold: true
                    color: parent.current ? c.accentText : c.text
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    onClicked: { ov.categoryFilter = modelData.name; ov.showAll = true; }
                }
            }
        }

        Label {
            id: listTitle
            anchors { left: parent.left; leftMargin: units.gu(2.5); top: chips.bottom; topMargin: units.gu(1.4) }
            text: (ov.categoryFilter !== "" ? ov.categoryFilter : i18n.tr("All passwords")) + " (" + entryList.count + ")"
            font.bold: true; fontSize: "medium"; color: c.text
        }
        Label {
            anchors { right: parent.right; rightMargin: units.gu(2.5); verticalCenter: listTitle.verticalCenter }
            text: i18n.tr("Back")
            fontSize: "small"; color: c.secondaryText
            MouseArea {
                anchors.fill: parent; anchors.margins: -units.gu(1.5)
                onClicked: { ov.showAll = false; ov.categoryFilter = ""; ov.query = ""; }
            }
        }
        ListView {
            id: entryList
            anchors { left: parent.left; right: parent.right; top: listTitle.bottom; bottom: parent.bottom
                      leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(0.6) }
            clip: true
            model: ov.categoryFilter === "" ? ov.entries
                   : ov.entries.filter(function (e) { return e.category === ov.categoryFilter; })
            footer: Item { width: 1; height: units.gu(14) }
            delegate: OnyxEntryItem {
                width: ListView.view ? ListView.view.width : 0
                order: index
                run: ov.listMode ? 1 : 0
                uuid: modelData.uuid
                title: modelData.title
                subtitle: modelData.username
                onEntryClicked: ov.entryClicked(uuid)
                onEntryLongPressed: ov.entryLongPressed(uuid, modelData.title, modelData.username)
                onCopyRequested: ov.copyRequested(uuid)
            }
        }
    }

    // ---- Floating pill bar --------------------------------------------
    Rectangle {
        id: pill
        z: 5
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: units.gu(2) }
        width: Math.min(parent.width - units.gu(4), units.gu(42))
        height: units.gu(7.6)
        radius: height / 2
        color: c.pill
        border.width: units.dp(1); border.color: c.border
        opacity: pillAp.progress
        transform: Translate { y: pillAp.offset }
        Appear { id: pillAp; delay: 200; distance: units.gu(8); duration: 560; easing: Easing.OutBack }

        readonly property real slot: width / 5
        property bool addPressed: false
        readonly property real dot: units.gu(5.4)

        // white bubble that glides to the selected tab
        Rectangle {
            width: pill.dot; height: width; radius: width / 2
            color: c.text
            anchors.verticalCenter: parent.verticalCenter
            x: ov.navTab * pill.slot + (pill.slot - pill.dot) / 2
            Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
        }
        // lighter circle behind the "+" button
        Rectangle {
            width: pill.dot; height: width; radius: width / 2
            color: pill.addPressed ? "#3a3a3d" : c.tile
            anchors.verticalCenter: parent.verticalCenter
            x: 4 * pill.slot + (pill.slot - pill.dot) / 2
            scale: pill.addPressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Repeater {
            model: [
                { icon: "home",           tab: 0 },
                { icon: "security-alert", tab: 1 },
                { icon: "reload",         tab: 2 },
                { icon: "settings",       tab: 3 },
                { icon: "add",            tab: 4 }
            ]
            delegate: Item {
                id: pItem
                x: index * pill.slot
                width: pill.slot
                height: pill.height
                property bool current: modelData.tab === ov.navTab
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.6); height: width
                    name: modelData.icon
                    color: pItem.current ? c.accentText : (modelData.tab === 4 ? c.text : c.secondaryText)
                    scale: pArea.pressed ? 0.8 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                MouseArea {
                    id: pArea
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.tab === 0) ov.resetTo(0);
                        else if (modelData.tab === 1) ov.resetTo(1);
                        else if (modelData.tab === 2) ov.generatorRequested();
                        else if (modelData.tab === 3) ov.settingsRequested();
                        else ov.addRequested();
                    }
                }
                // lets the circle behind "+" react to presses
                Binding { target: pill; property: "addPressed"; value: pArea.pressed; when: modelData.tab === 4 }
            }
        }
    }
}
