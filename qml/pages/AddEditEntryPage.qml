import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import "../themes"
import Lomiri.Components.Popups 1.3

Page {
    id: entryPage
    objectName: "addEditEntryPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var python
    property var mainView
    readonly property string skin: mainView ? (mainView.onyx ? "onyx" : mainView.emerald ? "emerald" : mainView.aegis ? "aegis" : mainView.bitwarden ? "bitwarden" : "") : ""
    readonly property bool themed: skin !== ""
    SkinColors { id: sc; skin: entryPage.skin === "" ? "onyx" : entryPage.skin }
    readonly property color labelColor: themed ? sc.secondaryText : theme.palette.normal.backgroundText
    property bool passwordRevealed: false

    // When set, we're editing; otherwise we're creating a new entry.
    property var existingEntry: null
    readonly property bool isEditing: existingEntry !== null

    header: PageHeader {
        id: pageHeader
        title: isEditing ? i18n.tr("Edit Entry") : i18n.tr("New Entry")
        StyleHints {
            backgroundColor: entryPage.themed ? sc.background : theme.palette.normal.background
            foregroundColor: entryPage.themed ? sc.text : theme.palette.normal.backgroundText
            dividerColor: entryPage.themed ? "transparent" : theme.palette.normal.base
        }
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

    function openGenerator() {
        var page = pageStack.push(Qt.resolvedUrl("GeneratorPage.qml"),
                                  { python: python, mainView: mainView, pickMode: true });
        page.passwordPicked.connect(function (pwd) {
            passwordField.text = pwd;
            pageStack.pop();
        });
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
        contentHeight: form.height + units.gu(2)
        clip: true
        boundsBehavior: entryPage.themed ? Flickable.StopAtBounds : Flickable.DragAndOvershootBounds

        Column {
            id: form
            width: parent.width
            spacing: entryPage.themed ? units.gu(1) : units.gu(1.5)

            Label { text: i18n.tr("Title"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            ThemedField {
                id: titleField
                width: parent.width
                skin: entryPage.skin
                text: isEditing ? existingEntry.title : ""
                placeholderText: i18n.tr("e.g. Personal Email")
            }

            Label { text: i18n.tr("Username / Email"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            ThemedField {
                id: usernameField
                width: parent.width
                skin: entryPage.skin
                text: isEditing ? existingEntry.username : ""
                placeholderText: i18n.tr("e.g. name@example.com")
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
            }

            Label { text: i18n.tr("Password"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            Row {
                id: passwordRow
                width: parent.width
                spacing: entryPage.themed ? units.gu(0.8) : units.gu(1)
                readonly property real btnW: entryPage.themed ? units.gu(5.6) : units.gu(4)
                ThemedField {
                    id: passwordField
                    width: parent.width - 2 * passwordRow.btnW - 2 * passwordRow.spacing
                    skin: entryPage.skin
                    echoMode: entryPage.passwordRevealed ? TextInput.Normal : TextInput.Password
                    text: isEditing ? existingEntry.password : ""
                    placeholderText: isEditing ? i18n.tr("(unchanged)") : i18n.tr("Password")
                }
                // Other themes: regular Lomiri buttons
                Button {
                    visible: !entryPage.themed
                    iconName: entryPage.passwordRevealed ? "eye-open" : "eye-closed"
                    width: passwordRow.btnW
                    onClicked: entryPage.passwordRevealed = !entryPage.passwordRevealed
                }
                Button {
                    visible: !entryPage.themed
                    iconName: "reload"
                    width: passwordRow.btnW
                    onClicked: entryPage.openGenerator()
                }
                // Onyx / Emerald: themed buttons
                ThemedButton {
                    skin: entryPage.skin
                    visible: entryPage.themed
                    width: passwordRow.btnW
                    iconName: entryPage.passwordRevealed ? "eye-open" : "eye-closed"
                    onClicked: entryPage.passwordRevealed = !entryPage.passwordRevealed
                }
                ThemedButton {
                    skin: entryPage.skin
                    visible: entryPage.themed
                    width: passwordRow.btnW
                    iconName: "reload"
                    onClicked: entryPage.openGenerator()
                }
            }

            Label { text: i18n.tr("URL"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            ThemedField {
                id: urlField
                width: parent.width
                skin: entryPage.skin
                inputMethodHints: Qt.ImhUrlCharactersOnly
                text: isEditing ? existingEntry.url : ""
            }

            Label { text: i18n.tr("Category / Tag"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            ThemedField {
                id: categoryField
                width: parent.width
                skin: entryPage.skin
                text: isEditing ? existingEntry.category : ""
                placeholderText: i18n.tr("e.g. Work, Banking, Social")
            }

            Label { text: i18n.tr("Notes"); color: entryPage.labelColor; fontSize: entryPage.themed ? "small" : "medium" }
            ThemedField {
                id: notesField
                width: parent.width
                skin: entryPage.skin
                multiline: true
                text: isEditing ? existingEntry.notes : ""
            }
        }
    }
}
