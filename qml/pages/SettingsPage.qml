import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import Lomiri.Components.Popups 1.3

Page {
    id: settingsPage
    objectName: "settingsPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    // Passed in from VaultPage (the MainView in Main.qml)
    property var mainView
    property var python

    readonly property string darkTheme: "Lomiri.Components.Themes.SuruDark"
    readonly property string lightTheme: "Lomiri.Components.Themes.Ambiance"

    header: PageHeader {
        id: settingsHeader
        title: i18n.tr("Settings")
    }

    Column {
        anchors { left: parent.left; right: parent.right; top: settingsHeader.bottom }

        // Dark / light mode
        ListItem {
            height: darkLayout.height + divider.height
            ListItemLayout {
                id: darkLayout
                title.text: i18n.tr("Dark mode")
                subtitle.text: i18n.tr("Switch between dark and light appearance")
                Switch {
                    id: darkSwitch
                    SlotsLayout.position: SlotsLayout.Trailing
                    onClicked: mainView.setTheme(checked ? darkTheme : lightTheme)
                }
                Binding {
                    target: darkSwitch
                    property: "checked"
                    value: mainView ? (mainView.themeName === darkTheme || mainView.bitwarden) : false
                }
            }
        }

        // Change master password
        ListItem {
            height: passwordLayout.height + divider.height
            onClicked: PopupUtils.open(changePasswordDialogComponent, settingsPage)
            ListItemLayout {
                id: passwordLayout
                title.text: i18n.tr("Change Password")
                subtitle.text: i18n.tr("Change the master password of your vault")
                ProgressionSlot {}
            }
        }

        // Themes page
        ListItem {
            height: themesLayout.height + divider.height
            onClicked: pageStack.push(Qt.resolvedUrl("ThemesPage.qml"), { mainView: mainView })
            ListItemLayout {
                id: themesLayout
                title.text: i18n.tr("Themes")
                subtitle.text: i18n.tr("Choose an app theme")
                ProgressionSlot {}
            }
        }
    }

    Connections {
        target: python
        onReceived: {
            if (data[0] === "master-password-changed") {
                passwordChangeNotice.color = theme.palette.normal.positive;
                passwordChangeNotice.text = i18n.tr("Master password changed.");
                passwordChangeNotice.visible = true;
            } else if (data[0] === "change-password-failed") {
                passwordChangeNotice.color = theme.palette.normal.negative;
                passwordChangeNotice.text = i18n.tr("Current password was incorrect -- nothing was changed.");
                passwordChangeNotice.visible = true;
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

    Label {
        id: passwordChangeNotice
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: units.gu(2) }
        visible: false
        wrapMode: Text.WordWrap
        Timer {
            running: passwordChangeNotice.visible
            interval: 3000
            onTriggered: passwordChangeNotice.visible = false
        }
    }
}
