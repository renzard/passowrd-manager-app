import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "../components"

Page {
    id: vaultPage
    objectName: "vaultPage"

    property var python
    property var entries: []

    header: PageHeader {
        id: pageHeader
        title: i18n.tr("Vault")
        leadingActionBar.actions: [
            Action {
                iconName: "lock"
                text: i18n.tr("Lock")
                onTriggered: python.call("vault_backend.lock_vault", [])
            },
            Action {
                iconName: "edit"
                text: i18n.tr("Change Password")
                onTriggered: PopupUtils.open(changePasswordDialogComponent, vaultPage)
            }
        ]
        trailingActionBar.actions: [
            Action {
                iconName: "add"
                text: i18n.tr("Add")
                onTriggered: pageStack.push(Qt.resolvedUrl("AddEditEntryPage.qml"),
                                             { python: python })
            },
            Action {
                iconName: "settings"
                text: i18n.tr("Generator")
                onTriggered: pageStack.push(Qt.resolvedUrl("GeneratorPage.qml"),
                                             { python: python })
            }
        ]
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
            case "master-password-changed":
                passwordChangeNotice.color = theme.palette.normal.positive;
                passwordChangeNotice.text = i18n.tr("Master password changed.");
                passwordChangeNotice.visible = true;
                break;
            case "change-password-failed":
                passwordChangeNotice.color = theme.palette.normal.negative;
                passwordChangeNotice.text = i18n.tr("Current password was incorrect -- nothing was changed.");
                passwordChangeNotice.visible = true;
                break;
            }
        }
    }

    Component {
        id: changePasswordDialogComponent
        Dialog {
            id: changePasswordDialog
            title: i18n.tr("Change Master Password")

            TextField {
                id: oldPasswordField
                echoMode: TextInput.Password
                placeholderText: i18n.tr("Current master password")
            }
            TextField {
                id: newPasswordField
                echoMode: TextInput.Password
                placeholderText: i18n.tr("New master password")
            }
            TextField {
                id: newPasswordConfirmField
                echoMode: TextInput.Password
                placeholderText: i18n.tr("Confirm new master password")
            }
            Label {
                id: dialogErrorLabel
                wrapMode: Text.WordWrap
                color: theme.palette.normal.negative
                visible: false
            }
            Button {
                text: i18n.tr("Change Password")
                color: theme.palette.normal.positive
                onClicked: {
                    if (newPasswordField.text !== newPasswordConfirmField.text) {
                        dialogErrorLabel.text = i18n.tr("New passwords do not match.");
                        dialogErrorLabel.visible = true;
                        return;
                    }
                    if (newPasswordField.text.length < 8) {
                        dialogErrorLabel.text = i18n.tr("Use at least 8 characters.");
                        dialogErrorLabel.visible = true;
                        return;
                    }
                    python.call("vault_backend.change_master_password",
                                [oldPasswordField.text, newPasswordField.text]);
                    PopupUtils.close(changePasswordDialog);
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(changePasswordDialog)
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
        python.call("vault_backend.list_entries", [searchField.text || ""]);
    }

    Component.onCompleted: refresh()

    Column {
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

    Label {
        id: passwordChangeNotice
        anchors { bottom: clearedNotice.top; horizontalCenter: parent.horizontalCenter; bottomMargin: units.gu(1) }
        visible: false
        wrapMode: Text.WordWrap
        Timer {
            running: passwordChangeNotice.visible
            interval: 3000
            onTriggered: passwordChangeNotice.visible = false
        }
    }

    Label {
        id: copiedNotice
        anchors { bottom: clearedNotice.top; horizontalCenter: parent.horizontalCenter; bottomMargin: units.gu(4) }
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
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: units.gu(2) }
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
