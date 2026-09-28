import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Page {
    id: entryPage
    objectName: "addEditEntryPage"

    property var python
    // When set, we're editing; otherwise we're creating a new entry.
    property var existingEntry: null
    readonly property bool isEditing: existingEntry !== null

    header: PageHeader {
        id: pageHeader
        title: isEditing ? i18n.tr("Edit Entry") : i18n.tr("New Entry")
        trailingActionBar.actions: [
            Action {
                visible: isEditing
                iconName: "delete"
                text: i18n.tr("Delete")
                onTriggered: PopupUtils.open(deleteDialog)
            },
            Action {
                iconName: "tick"
                text: i18n.tr("Save")
                enabled: titleField.text.length > 0
                onTriggered: save()
            }
        ]
    }

    Connections {
        target: python
        onReceived: {
            if (data[0] === "entry-saved" || data[0] === "entry-deleted") {
                pageStack.pop();
            }
        }
    }

    Component {
        id: deleteDialog
        Dialog {
            id: dialog
            title: i18n.tr("Delete entry?")
            text: i18n.tr("This cannot be undone.")
            Button {
                text: i18n.tr("Delete")
                color: theme.palette.normal.negative
                onClicked: {
                    PopupUtils.close(dialog);
                    python.call("vault_backend.delete_entry", [existingEntry.uuid]);
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    function save() {
        if (isEditing) {
            python.call("vault_backend.update_entry", [
                existingEntry.uuid, titleField.text, usernameField.text,
                passwordField.text, urlField.text, notesField.text, categoryField.text
            ]);
        } else {
            python.call("vault_backend.add_entry", [
                titleField.text, usernameField.text, passwordField.text,
                urlField.text, notesField.text, categoryField.text
            ]);
        }
    }

    Flickable {
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(2)
        }
        contentHeight: form.height
        clip: true

        Column {
            id: form
            width: parent.width
            spacing: units.gu(1.5)

            Label { text: i18n.tr("Title") }
            TextField {
                id: titleField
                width: parent.width
                text: isEditing ? existingEntry.title : ""
                placeholderText: i18n.tr("e.g. Personal Email")
            }

            Label { text: i18n.tr("Username / Email") }
            TextField {
                id: usernameField
                width: parent.width
                text: isEditing ? existingEntry.username : ""
                placeholderText: i18n.tr("e.g. name@example.com")
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
            }

            Label { text: i18n.tr("Password") }
            Row {
                width: parent.width
                spacing: units.gu(1)
                TextField {
                    id: passwordField
                    width: parent.width - revealButton.width - generateButton.width - units.gu(2)
                    echoMode: revealButton.revealed ? TextInput.Normal : TextInput.Password
                    text: isEditing ? existingEntry.password : ""
                    placeholderText: isEditing ? i18n.tr("(unchanged)") : i18n.tr("Password")
                }
                Button {
                    id: revealButton
                    property bool revealed: false
                    iconName: revealed ? "eye-open" : "eye-closed"
                    width: units.gu(4)
                    onClicked: revealed = !revealed
                }
                Button {
                    id: generateButton
                    iconName: "reload"
                    width: units.gu(4)
                    onClicked: {
                        var page = pageStack.push(Qt.resolvedUrl("GeneratorPage.qml"),
                                                    { python: python, pickMode: true });
                        page.passwordPicked.connect(function (pwd) {
                            passwordField.text = pwd;
                            pageStack.pop();
                        });
                    }
                }
            }

            Label { text: i18n.tr("URL") }
            TextField {
                id: urlField
                width: parent.width
                inputMethodHints: Qt.ImhUrlCharactersOnly
                text: isEditing ? existingEntry.url : ""
            }

            Label { text: i18n.tr("Category / Tag") }
            TextField {
                id: categoryField
                width: parent.width
                text: isEditing ? existingEntry.category : ""
                placeholderText: i18n.tr("e.g. Work, Banking, Social")
            }

            Label { text: i18n.tr("Notes") }
            TextArea {
                id: notesField
                width: parent.width
                height: units.gu(10)
                text: isEditing ? existingEntry.notes : ""
            }
        }
    }
}
