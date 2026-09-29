import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import Lomiri.Components.Popups 1.3

Page {
    id: unlockPage
    objectName: "unlockPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var python
    property bool vaultExists: false
    property bool busy: false
    property bool showBackup: false

    header: PageHeader {
        title: i18n.tr("Password Manager")
    }

    Connections {
        target: python
        onReceived: {
            switch (data[0]) {
            case "vault-unlocked":
                busy = false;
                break;
            case "vault-unlock-failed":
                busy = false;
                if (data[1] === "wrong-password") {
                    errorLabel.text = i18n.tr("Incorrect master password.");
                } else if (data[1] === "not-found") {
                    errorLabel.text = i18n.tr("No vault found at that location.");
                } else if (data[1] === "already-exists") {
                    errorLabel.text = i18n.tr("A vault already exists.");
                } else {
                    errorLabel.text = i18n.tr("That file isn't a valid vault.");
                }
                errorLabel.visible = true;
                passwordField.selectAll();
                break;
            case "backend-error":
                busy = false;
                errorLabel.text = i18n.tr("Something went wrong: ") + data[2];
                errorLabel.visible = true;
                break;
            case "vault-exported":
                busy = false;
                backupStatusLabel.color = theme.palette.normal.positive;
                backupStatusLabel.text = i18n.tr("Backup saved to: ") + data[1];
                backupStatusLabel.visible = true;
                break;
            case "vault-imported":
                busy = false;
                backupStatusLabel.color = theme.palette.normal.positive;
                backupStatusLabel.text = i18n.tr("Vault restored. You can unlock it now with its master password.");
                backupStatusLabel.visible = true;
                vaultExists = true;
                break;
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: units.gu(2)
        contentHeight: mainColumn.height + units.gu(4)

        Column {
            id: mainColumn
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - units.gu(6)
            spacing: units.gu(2)

            Icon {
                name: "lock"
                width: units.gu(8)
                height: units.gu(8)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: vaultExists
                      ? i18n.tr("Enter your master password to unlock the vault")
                      : i18n.tr("Choose a master password for a new vault")
                fontSize: "medium"
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !vaultExists
                fontSize: "small"
                color: theme.palette.normal.backgroundSecondaryText
                text: i18n.tr("All entries are encrypted with this password. There is no way to recover them without it, so don't forget it.")
            }

            TextField {
                id: passwordField
                width: parent.width
                echoMode: TextInput.Password
                placeholderText: i18n.tr("Master password")
                onAccepted: confirmButton.clicked()
                enabled: !busy
            }

            TextField {
                id: confirmField
                width: parent.width
                visible: !vaultExists
                echoMode: TextInput.Password
                placeholderText: i18n.tr("Confirm master password")
                enabled: !busy
            }

            Label {
                id: errorLabel
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: theme.palette.normal.negative
                visible: false
            }

            Button {
                id: confirmButton
                width: parent.width
                color: theme.palette.normal.positive
                text: busy ? i18n.tr("Please wait...")
                           : (vaultExists ? i18n.tr("Unlock") : i18n.tr("Create Vault"))
                enabled: !busy && passwordField.text.length > 0
                onClicked: {
                    errorLabel.visible = false;
                    backupStatusLabel.visible = false;
                    if (!vaultExists) {
                        if (passwordField.text !== confirmField.text) {
                            errorLabel.text = i18n.tr("Passwords do not match.");
                            errorLabel.visible = true;
                            return;
                        }
                        if (passwordField.text.length < 8) {
                            errorLabel.text = i18n.tr("Use at least 8 characters.");
                            errorLabel.visible = true;
                            return;
                        }
                        busy = true;
                        python.call("vault_backend.create_vault", [null, passwordField.text]);
                    } else {
                        busy = true;
                        python.call("vault_backend.unlock_vault", [null, passwordField.text]);
                    }
                    passwordField.text = "";
                    confirmField.text = "";
                }
            }

            Button {
                width: parent.width
                text: showBackup ? i18n.tr("Hide backup / restore")
                                  : i18n.tr("Backup / restore vault file")
                onClicked: showBackup = !showBackup
            }

            Column {
                width: parent.width
                spacing: units.gu(1)
                visible: showBackup

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: theme.palette.normal.backgroundSecondaryText
                    text: i18n.tr("The vault is one encrypted file. Copy it somewhere safe before a factory reset or reinstall, then restore it afterwards -- unlocking with the same master password brings back the same entries.")
                }

                TextField {
                    id: backupPathField
                    width: parent.width
                    placeholderText: i18n.tr("Backup file path, e.g. /home/phablet/Documents/vault.pmvault")
                    text: "/home/phablet/Documents/vault.pmvault"
                    enabled: !busy
                }

                Row {
                    width: parent.width
                    spacing: units.gu(1)

                    Button {
                        width: (parent.width - units.gu(1)) / 2
                        text: i18n.tr("Save backup")
                        enabled: !busy && vaultExists
                        onClicked: {
                            busy = true;
                            backupStatusLabel.visible = false;
                            python.call("vault_backend.export_vault", [backupPathField.text]);
                        }
                    }

                    Button {
                        width: (parent.width - units.gu(1)) / 2
                        text: i18n.tr("Restore backup")
                        enabled: !busy
                        onClicked: {
                            busy = true;
                            backupStatusLabel.visible = false;
                            python.call("vault_backend.import_vault", [backupPathField.text, null]);
                        }
                    }
                }

                Label {
                    id: backupStatusLabel
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: false
                }
            }
        }
    }
}
