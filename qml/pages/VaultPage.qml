import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../components"
import "../themes"

Page {
    id: vaultPage
    objectName: "vaultPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var python
    property var mainView
    property var entries: []

    // True when the "Bitwarden" theme is active: header actions move to the
    // floating bottom bar / round button and the list becomes a rounded card.
    readonly property bool bw: mainView ? mainView.bitwarden : false
    readonly property bool aegis: mainView ? mainView.aegis : false
    readonly property bool emerald: mainView ? mainView.emerald : false
    readonly property bool onyx: mainView ? mainView.onyx : false
    property var overview: ({ total: 0, atRisk: 0, secure: 0, categories: [], recent: [] })
    property bool showAll: false      // Aegis: "Passwords" tab = full list
    property string categoryFilter: ""
    property string searchQuery: onyx ? onyxContent.query : emerald ? emeraldContent.query : (aegis ? aegisHome.query : (bw ? bwSearch.text : searchField.text))
    onSearchQueryChanged: refresh()

    BitwardenColors { id: bwc }
    AegisColors { id: ac }
    EmeraldColors { id: ec }
    OnyxColors { id: oc }

    Action {
        id: lockAction
        iconName: "lock"
        text: i18n.tr("Lock")
        onTriggered: python.call("vault_backend.lock_vault", [])
    }
    Action {
        id: addAction
        iconName: "add"
        text: i18n.tr("Add")
        onTriggered: pageStack.push(Qt.resolvedUrl("AddEditEntryPage.qml"),
                                     { python: python, mainView: mainView })
    }
    Action {
        id: generatorAction
        iconName: "reload"
        text: i18n.tr("Generator")
        onTriggered: pageStack.push(Qt.resolvedUrl("GeneratorPage.qml"),
                                     { python: python, mainView: mainView })
    }
    Action {
        id: settingsAction
        iconName: "settings"
        text: i18n.tr("Settings")
        onTriggered: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"),
                                     { mainView: mainView, python: python })
    }

    header: PageHeader {
        id: pageHeader
        title: (vaultPage.bw || vaultPage.aegis || vaultPage.emerald || vaultPage.onyx) ? "" : i18n.tr("Vault")
        leadingActionBar.actions: (vaultPage.bw || vaultPage.aegis || vaultPage.emerald || vaultPage.onyx) ? [] : [lockAction]
        trailingActionBar.actions: (vaultPage.bw || vaultPage.aegis || vaultPage.emerald || vaultPage.onyx) ? [] : [addAction, generatorAction, settingsAction]
        StyleHints {
            backgroundColor: vaultPage.onyx ? oc.background
                             : vaultPage.emerald ? ec.background
                             : vaultPage.aegis ? ac.background
                             : (vaultPage.bw ? bwc.background : theme.palette.normal.background)
        }
    }

    SelfClearingClipboard {
        id: clipboard
        onCleared: clearedNotice.visible = true
    }

    Connections {
        target: python
        onReceived: {
            switch (data[0]) {
            case "entries-list-result":
                entries = data[1];
                break;
            case "entry-detail-result":
                pageStack.push(Qt.resolvedUrl("AddEditEntryPage.qml"),
                                { python: python, mainView: mainView, existingEntry: data[1] });
                break;
            case "overview-result":
                overview = data[1];
                break;
            case "entry-saved":
            case "entry-deleted":
                refresh();
                break;
            case "secret-ready":
                clipboard.copySecret(data[2]);
                copiedNotice.text = (data[1] === "password")
                                    ? i18n.tr("Password copied")
                                    : i18n.tr("Username copied");
                copiedNotice.visible = true;
                break;
            }
        }
    }

    Component {
        id: quickCopyDialogComponent
        Dialog {
            id: quickCopyDialog
            property string entryUuid
            title: entryTitle
            property string entryTitle: ""
            property string entryUsername: ""
            text: entryUsername

            Button {
                text: i18n.tr("Copy username / email")
                color: theme.palette.normal.focus
                onClicked: {
                    python.call("vault_backend.get_entry_secret", [quickCopyDialog.entryUuid, "username"]);
                    PopupUtils.close(quickCopyDialog);
                }
            }
            Button {
                text: i18n.tr("Copy password")
                color: theme.palette.normal.positive
                onClicked: {
                    python.call("vault_backend.get_entry_secret", [quickCopyDialog.entryUuid, "password"]);
                    PopupUtils.close(quickCopyDialog);
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(quickCopyDialog)
            }
        }
    }

    function refresh() {
        python.call("vault_backend.list_entries", [vaultPage.searchQuery || ""]);
        if (aegis || emerald || onyx) python.call("vault_backend.get_overview", []);
    }
    onAegisChanged: refresh()
    onEmeraldChanged: refresh()
    onOnyxChanged: refresh()
    // Refresh the home screen when coming back from another page
    onActiveChanged: if (active && (aegis || emerald || onyx)) refresh()

    Component.onCompleted: refresh()

    Column {
        visible: !vaultPage.bw && !vaultPage.aegis && !vaultPage.emerald && !vaultPage.onyx
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom }
        spacing: 0

        TextField {
            id: searchField
            anchors { left: parent.left; right: parent.right; margins: units.gu(1) }
            placeholderText: i18n.tr("Search title, username, category...")
            onTextChanged: refresh()
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: entries.length === 0
            text: i18n.tr("No entries yet. Tap + to add one.")
            color: theme.palette.normal.backgroundSecondaryText
        }

        ListView {
            width: parent.width
            height: vaultPage.height - pageHeader.height - searchField.height - units.gu(2)
            clip: true
            model: entries
            delegate: EntryListItem {
                width: parent ? parent.width : 0
                uuid: modelData.uuid
                title: modelData.title
                username: modelData.username
                category: modelData.category
                onEntryClicked: python.call("vault_backend.get_entry", [uuid])
                onCopyUsername: python.call("vault_backend.get_entry_secret", [uuid, "username"])
                onCopyPassword: python.call("vault_backend.get_entry_secret", [uuid, "password"])
                onEntryLongPressed: PopupUtils.open(quickCopyDialogComponent, vaultPage,
                                                    { entryUuid: uuid, entryTitle: title, entryUsername: username })
            }
        }
    }

    // ---------------------------------------------------------------
    // Bitwarden-style layout (only visible with the "Bitwarden" theme)
    // ---------------------------------------------------------------
    Label {
        visible: vaultPage.bw
        z: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: (pageHeader.height - height) / 2
        }
        text: i18n.tr("My vault")
        font.bold: true
        fontSize: "large"
        color: bwc.text
    }

    // Round button top-right: locks the vault
    Rectangle {
        visible: vaultPage.bw
        z: 10
        width: units.gu(5); height: width; radius: width / 2
        color: "#f2c9a0"
        scale: lockArea.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
        anchors {
            right: parent.right; rightMargin: units.gu(2)
            top: parent.top; topMargin: (pageHeader.height - height) / 2
        }
        Icon {
            anchors.centerIn: parent
            width: units.gu(2.4); height: width
            name: "lock"
            color: "#4a2f17"
        }
        MouseArea { id: lockArea; anchors.fill: parent; onClicked: lockAction.trigger() }
    }

    Item {
        id: bwContent
        visible: vaultPage.bw

        // Drives the intro animations of the round button and bottom bar
        property bool shown: false
        onVisibleChanged: shown = visible
        Component.onCompleted: shown = visible
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; bottom: parent.bottom }

        // Search pill
        Rectangle {
            id: searchPill
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(1.5)
            }
            height: units.gu(6)
            radius: height / 2
            color: bwc.field
            border.width: bwSearch.activeFocus ? units.dp(2) : units.dp(1)
            border.color: bwSearch.activeFocus ? bwc.accent : Qt.rgba(1, 1, 1, 0.12)
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on border.width { NumberAnimation { duration: 200 } }

            Icon {
                id: searchIcon
                anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                width: units.gu(2.4); height: width
                name: "find"
                color: bwc.text
            }
            TextInput {
                id: bwSearch
                anchors {
                    left: searchIcon.right; leftMargin: units.gu(1.5)
                    right: parent.right; rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                color: bwc.text
                selectionColor: bwc.accent
                font.pixelSize: units.gu(2)
                clip: true
                onTextChanged: refresh()

                Label {
                    visible: bwSearch.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: i18n.tr("Search")
                    fontSize: "medium"
                    color: bwc.secondaryText
                }
            }
        }

        Label {
            id: sectionLabel
            anchors { left: parent.left; top: searchPill.bottom; leftMargin: units.gu(2.5); topMargin: units.gu(2) }
            text: i18n.tr("ALL ITEMS (%1)").arg(entries.length)
            fontSize: "small"
            color: bwc.secondaryText
        }

        // Rounded card with the entries
        Rectangle {
            id: listCard
            anchors {
                left: parent.left; right: parent.right
                top: sectionLabel.bottom; bottom: parent.bottom
                leftMargin: units.gu(1.5); rightMargin: units.gu(1.5); topMargin: units.gu(1)
            }
            radius: units.gu(2)
            color: bwc.card
            clip: true

            Label {
                anchors.centerIn: parent
                visible: entries.length === 0
                text: i18n.tr("No entries yet. Tap + to add one.")
                color: bwc.secondaryText
            }

            ListView {
                anchors.fill: parent
                clip: true
                model: entries
                footer: Item { width: 1; height: units.gu(14) }   // keeps last rows clear of the bottom bar
                delegate: BitwardenEntryItem {
                    width: ListView.view ? ListView.view.width : 0
                    order: index
                    uuid: modelData.uuid
                    title: modelData.title
                    username: modelData.username
                    category: modelData.category
                    showDivider: index < entries.length - 1
                    onEntryClicked: python.call("vault_backend.get_entry", [uuid])
                    onEntryLongPressed: PopupUtils.open(quickCopyDialogComponent, vaultPage,
                                                        { entryUuid: uuid, entryTitle: title, entryUsername: username })
                }
            }
        }

        // Round "+" button
        Rectangle {
            id: fab
            z: 5
            width: units.gu(7.5); height: width; radius: width / 2
            color: bwc.accent
            anchors { right: parent.right; rightMargin: units.gu(2.5); bottom: bottomBar.top; bottomMargin: units.gu(2) }
            // Pops in when the page appears, shrinks slightly while pressed
            scale: fabArea.pressed ? 0.9 : (bwContent.shown ? 1 : 0)
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
            Icon {
                anchors.centerIn: parent
                width: units.gu(3.5); height: width
                name: "add"
                color: bwc.accentText
                rotation: fabArea.pressed ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            MouseArea { id: fabArea; anchors.fill: parent; onClicked: addAction.trigger() }
        }

        // Floating bottom bar: My vault / Generator / Settings
        Rectangle {
            id: bottomBar
            z: 5
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: units.gu(2); rightMargin: units.gu(2)
                bottomMargin: bwContent.shown ? units.gu(2) : -units.gu(12)
            }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            height: units.gu(9)
            radius: units.gu(4.5)
            color: bwc.nav
            border.width: units.dp(1)
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Item {
                id: tabs
                anchors { fill: parent; margins: units.gu(0.8) }
                property int selectedTab: 0

                // Highlight pill that slides to the tapped tab
                Rectangle {
                    width: tabs.width / 3
                    height: tabs.height
                    radius: height / 2
                    color: bwc.navSelected
                    x: tabs.selectedTab * width
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                // Small delay so the highlight is seen moving before the next page opens
                Timer {
                    id: openTimer
                    interval: 180
                    property var pendingAction: null
                    onTriggered: if (pendingAction) pendingAction.trigger()
                }

                // Coming back to the vault: slide the highlight home again
                Connections {
                    target: vaultPage
                    onActiveChanged: if (vaultPage.active) tabs.selectedTab = 0
                }

                Repeater {
                    model: [
                        { label: i18n.tr("My vault"),  icon: "lock",     act: null },
                        { label: i18n.tr("Generator"), icon: "reload",   act: generatorAction },
                        { label: i18n.tr("Settings"),  icon: "settings", act: settingsAction }
                    ]
                    delegate: Item {
                        x: index * tabs.width / 3
                        width: tabs.width / 3
                        height: tabs.height
                        property bool current: tabs.selectedTab === index

                        Column {
                            anchors.centerIn: parent
                            spacing: units.gu(0.4)
                            scale: current ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: units.gu(3); height: width
                                name: modelData.icon
                                color: current ? bwc.accent : bwc.secondaryText
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                fontSize: "x-small"
                                color: current ? bwc.accent : bwc.secondaryText
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                tabs.selectedTab = index;
                                if (modelData.act) {
                                    openTimer.pendingAction = modelData.act;
                                    openTimer.restart();
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // ---------------------------------------------------------------
    // "Aegis" layout (only visible with the "Aegis" theme)
    // ---------------------------------------------------------------
    Item {
        id: aegisContent
        visible: vaultPage.aegis
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; bottom: parent.bottom }
        property bool listMode: vaultPage.showAll || vaultPage.categoryFilter !== "" || aegisHome.query.length > 0
        property int navTab: listMode ? 1 : 0

        AegisHome {
            id: aegisHome
            anchors.fill: parent
            opacity: aegisContent.listMode ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            overview: vaultPage.overview
            userName: mainView ? mainView.displayName : ""
            onAddRequested: addAction.trigger()
            onEntryClicked: python.call("vault_backend.get_entry", [uuid])
            onCategoryClicked: { vaultPage.categoryFilter = name; }
        }

        // Full list: "Passwords" tab, a tapped category, or an active search
        Item {
            id: aegisListPane
            anchors.fill: parent
            opacity: aegisContent.listMode ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - aegisListPane.opacity) * units.gu(2.5) }

            Rectangle {
                id: aSearch
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(1) }
                height: units.gu(6); radius: units.gu(1.2)
                color: ac.field; border.width: units.dp(1); border.color: ac.border
                Icon { id: aIcon; anchors { left: parent.left; leftMargin: units.gu(1.5); verticalCenter: parent.verticalCenter }
                       width: units.gu(2.4); height: width; name: "find"; color: ac.secondaryText }
                TextInput {
                    anchors { left: aIcon.right; leftMargin: units.gu(1); right: parent.right; rightMargin: units.gu(1); verticalCenter: parent.verticalCenter }
                    color: ac.text; selectionColor: ac.accent; font.pixelSize: units.gu(1.9); clip: true
                    text: aegisHome.query
                    onTextChanged: if (activeFocus) aegisHome.query = text
                }
            }
            Label {
                id: aTitle
                anchors { left: parent.left; leftMargin: units.gu(2.5); top: aSearch.bottom; topMargin: units.gu(1.5) }
                text: (vaultPage.categoryFilter !== "" ? vaultPage.categoryFilter : i18n.tr("Passwords")) + " (" + aegisList.count + ")"
                font.bold: true; color: ac.text
            }
            Label {
                anchors { right: parent.right; rightMargin: units.gu(2.5); verticalCenter: aTitle.verticalCenter }
                visible: vaultPage.categoryFilter !== ""
                text: i18n.tr("Show all")
                fontSize: "small"; color: ac.accentSoft
                MouseArea { anchors.fill: parent; anchors.margins: -units.gu(1); onClicked: vaultPage.categoryFilter = "" }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: aTitle.bottom; bottom: parent.bottom
                          leftMargin: units.gu(2); rightMargin: units.gu(2); topMargin: units.gu(1) }
                radius: units.gu(1.5); color: ac.card
                border.width: units.dp(1); border.color: ac.border
                clip: true
                ListView {
                    id: aegisList
                    anchors.fill: parent
                    clip: true
                    model: vaultPage.categoryFilter === "" ? entries
                           : entries.filter(function (e) { return e.category === vaultPage.categoryFilter; })
                    footer: Item { width: 1; height: units.gu(12) }
                    delegate: BitwardenEntryItem {
                        width: ListView.view ? ListView.view.width : 0
                        order: index
                        run: aegisContent.listMode ? 1 : 0
                        uuid: modelData.uuid
                        title: modelData.title
                        username: modelData.username
                        category: modelData.category
                        showDivider: index < aegisList.count - 1
                        onEntryClicked: python.call("vault_backend.get_entry", [uuid])
                        onEntryLongPressed: PopupUtils.open(quickCopyDialogComponent, vaultPage,
                                                            { entryUuid: uuid, entryTitle: title, entryUsername: username })
                    }
                }
            }
        }

        // Bottom navigation: Home / Passwords / Generator / Settings
        Rectangle {
            id: aNav
            z: 5
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: units.gu(8)
            color: ac.nav
            // slides up when the page opens
            opacity: navAp.progress
            transform: Translate { y: navAp.offset }
            Appear { id: navAp; delay: 250; distance: units.gu(8); duration: 520 }

            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: units.dp(1); color: ac.border }

            // One indicator that glides between the tabs
            Rectangle {
                id: navIndicator
                y: 0
                width: aNav.width / 4 * 0.6; height: units.dp(3)
                radius: height / 2
                color: ac.accent
                x: aegisContent.navTab * aNav.width / 4 + aNav.width / 4 * 0.2
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
            }
            // soft light under the active tab
            Rectangle {
                y: 0
                height: aNav.height
                width: aNav.width / 4
                x: aegisContent.navTab * aNav.width / 4
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0.43, 0.37, 0.99, 0.18) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            Repeater {
                model: [
                    { label: i18n.tr("Home"),      icon: "home",     tab: 0 },
                    { label: i18n.tr("Passwords"), icon: "lock",     tab: 1 },
                    { label: i18n.tr("Generator"), icon: "reload",   tab: 2 },
                    { label: i18n.tr("Settings"),  icon: "settings", tab: 3 }
                ]
                delegate: Item {
                    id: navItem
                    x: index * aNav.width / 4
                    width: aNav.width / 4
                    height: aNav.height
                    property bool current: modelData.tab === aegisContent.navTab
                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.4)
                        // bounce when selected, shrink while pressed
                        property real pressScale: navArea.pressed ? 0.85 : 1
                        Behavior on pressScale { NumberAnimation { duration: 120 } }
                        scale: (navItem.current ? 1.12 : 1) * pressScale
                        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter; width: units.gu(3); height: width
                            name: modelData.icon
                            color: navItem.current ? ac.accentSoft : ac.secondaryText
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label
                            fontSize: "x-small"
                            color: navItem.current ? ac.accentSoft : ac.secondaryText
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.tab === 0) { vaultPage.showAll = false; vaultPage.categoryFilter = ""; aegisHome.query = ""; }
                            else if (modelData.tab === 1) { vaultPage.showAll = true; vaultPage.categoryFilter = ""; }
                            else if (modelData.tab === 2) generatorAction.trigger();
                            else settingsAction.trigger();
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // "Emerald" layout (only visible with the "Emerald" theme)
    // ---------------------------------------------------------------
    EmeraldVault {
        id: emeraldContent
        visible: vaultPage.emerald
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; bottom: parent.bottom }
        overview: vaultPage.overview
        entries: vaultPage.entries
        userName: mainView ? mainView.displayName : ""
        onAddRequested: addAction.trigger()
        onGeneratorRequested: generatorAction.trigger()
        onSettingsRequested: settingsAction.trigger()
        onLockRequested: lockAction.trigger()
        onEntryClicked: python.call("vault_backend.get_entry", [uuid])
        onEntryLongPressed: PopupUtils.open(quickCopyDialogComponent, vaultPage,
                                            { entryUuid: uuid, entryTitle: title, entryUsername: username })
    }

    // ---------------------------------------------------------------
    // "Onyx" layout (only visible with the "Onyx" theme)
    // ---------------------------------------------------------------
    OnyxVault {
        id: onyxContent
        visible: vaultPage.onyx
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; bottom: parent.bottom }
        overview: vaultPage.overview
        entries: vaultPage.entries
        userName: mainView ? mainView.displayName : ""
        onAddRequested: addAction.trigger()
        onGeneratorRequested: generatorAction.trigger()
        onSettingsRequested: settingsAction.trigger()
        onLockRequested: lockAction.trigger()
        onEntryClicked: python.call("vault_backend.get_entry", [uuid])
        onCopyRequested: python.call("vault_backend.get_entry_secret", [uuid, "password"])
        onEntryLongPressed: PopupUtils.open(quickCopyDialogComponent, vaultPage,
                                            { entryUuid: uuid, entryTitle: title, entryUsername: username })
    }

    Label {
        id: copiedNotice
        z: 20
        anchors { bottom: clearedNotice.top; horizontalCenter: parent.horizontalCenter; bottomMargin: units.gu(1) }
        visible: false
        color: theme.palette.normal.positive
        Timer {
            running: copiedNotice.visible
            interval: 2000
            onTriggered: copiedNotice.visible = false
        }
    }

    Label {
        id: clearedNotice
        z: 20
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter
                  bottomMargin: (vaultPage.aegis || vaultPage.emerald || vaultPage.onyx) ? units.gu(10) : (vaultPage.bw ? units.gu(13) : units.gu(2)) }
        visible: false
        text: i18n.tr("Clipboard cleared")
        color: theme.palette.normal.backgroundSecondaryText
        Timer {
            running: clearedNotice.visible
            interval: 2000
            onTriggered: clearedNotice.visible = false
        }
    }
}
