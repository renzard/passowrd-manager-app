import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import "../themes"
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
    readonly property string skin: mainView ? (mainView.onyx ? "onyx" : mainView.emerald ? "emerald" : mainView.aegis ? "aegis" : mainView.bitwarden ? "bitwarden" : "") : ""
    readonly property bool themed: skin !== ""
    SkinColors { id: sc; skin: settingsPage.skin === "" ? "onyx" : settingsPage.skin }

    readonly property string darkTheme: "Lomiri.Components.Themes.SuruDark"
    readonly property string lightTheme: "Lomiri.Components.Themes.Ambiance"

    header: PageHeader {
        id: settingsHeader
        title: i18n.tr("Settings")
        StyleHints {
            backgroundColor: settingsPage.themed ? sc.background : theme.palette.normal.background
            foregroundColor: settingsPage.themed ? sc.text : theme.palette.normal.backgroundText
            dividerColor: settingsPage.themed ? "transparent" : theme.palette.normal.base
        }
    }

    // ---------------------------------------------------------------
    // themed layout (Onyx / Emerald)
    // ---------------------------------------------------------------
    Flickable {
        visible: settingsPage.themed
        anchors { left: parent.left; right: parent.right; top: settingsHeader.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: themedSettings.height + units.gu(4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: themedSettings
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: units.gu(0.4)

            Item { width: 1; height: units.gu(0.4) }

            ThemedRow {
                skin: settingsPage.skin
                width: parent.width
                pressable: false
                title: i18n.tr("Dark mode")
                subtitle: i18n.tr("Switch between dark and light appearance")
                ThemedSwitch {
                    skin: settingsPage.skin
                    checked: mainView ? (mainView.themeName === darkTheme || mainView.bitwarden || mainView.aegis || mainView.emerald || mainView.onyx) : false
                    onClicked: mainView.setTheme(checked ? lightTheme : darkTheme)
                }
            }

            // Display name: needs room for the field, so it is a custom card
            Rectangle {
                width: parent.width
                height: units.gu(15.4)
                radius: sc.cardRadius
                border.width: units.dp(1); border.color: sc.border
                gradient: Gradient {
                    GradientStop { position: 0; color: sc.cardTop }
                    GradientStop { position: 1; color: sc.cardBottom }
                }
                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top
                              leftMargin: units.gu(2.2); rightMargin: units.gu(2); topMargin: units.gu(1.8) }
                    spacing: units.gu(0.4)
                    Label { width: parent.width; text: i18n.tr("Display name"); font.bold: true
                            fontSize: "medium"; color: sc.text }
                    Label { width: parent.width; text: i18n.tr("Shown in the greeting (Aegis / Emerald / Onyx themes)")
                            fontSize: "x-small"; color: sc.secondaryText; wrapMode: Text.WordWrap }
                }
                ThemedField {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: units.gu(1.6); rightMargin: units.gu(1.6); bottomMargin: units.gu(1.4) }
                    skin: settingsPage.skin
                    text: mainView ? mainView.displayName : ""
                    placeholderText: i18n.tr("Your name")
                    onTextChanged: if (mainView && text !== mainView.displayName) mainView.displayName = text
                }
            }

            ThemedRow {
                skin: settingsPage.skin
                width: parent.width
                chevron: true
                title: i18n.tr("Change Password")
                subtitle: i18n.tr("Change the master password of your vault")
                onClicked: PopupUtils.open(changePasswordDialogComponent, settingsPage)
            }

            ThemedRow {
                skin: settingsPage.skin
                width: parent.width
                chevron: true
                title: i18n.tr("Themes")
                subtitle: i18n.tr("Choose an app theme")
                onClicked: pageStack.push(Qt.resolvedUrl("ThemesPage.qml"), { mainView: mainView })
            }
        }
    }

    Column {
        visible: !settingsPage.themed
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
                    value: mainView ? (mainView.themeName === darkTheme || mainView.bitwarden || mainView.aegis || mainView.emerald || mainView.onyx) : false
                }
            }
        }

        // Name shown in the greeting of the Aegis home screen
        ListItem {
            height: nameLayout.height + divider.height
            ListItemLayout {
                id: nameLayout
                title.text: i18n.tr("Display name")
                subtitle.text: i18n.tr("Shown in the greeting (Aegis / Emerald / Onyx themes)")
                TextField {
                    SlotsLayout.position: SlotsLayout.Trailing
                    width: units.gu(16)
                    text: mainView ? mainView.displayName : ""
                    onTextChanged: if (mainView && activeFocus) mainView.displayName = text
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
