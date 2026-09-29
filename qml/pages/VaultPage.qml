import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../components"
import "../themes"

Page {
    id: vaultPage
    objectName: "vaultPage"

    property var python
    property var mainView
    property var entries: []

    // True when the "Bitwarden" theme is active: header actions move to the
    // floating bottom bar / round button and the list becomes a rounded card.
    readonly property bool bw: mainView ? mainView.bitwarden : false
    property string searchQuery: bw ? bwSearch.text : searchField.text

    BitwardenColors { id: bwc }

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
                                     { python: python })
    }
    Action {
        id: generatorAction
        iconName: "reload"
        text: i18n.tr("Generator")
        onTriggered: pageStack.push(Qt.resolvedUrl("GeneratorPage.qml"),
                                     { python: python })
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
        title: vaultPage.bw ? "" : i18n.tr("Vault")
        leadingActionBar.actions: vaultPage.bw ? [] : [lockAction]
        trailingActionBar.actions: vaultPage.bw ? [] : [addAction, generatorAction, settingsAction]
        StyleHints {
            backgroundColor: vaultPage.bw ? bwc.background : theme.palette.normal.background
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
                                { python: python, existingEntry: data[1] });
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
    }

    Component.onCompleted: refresh()

    Column {
        visible: !vaultPage.bw
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
                  bottomMargin: vaultPage.bw ? units.gu(13) : units.gu(2) }
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
