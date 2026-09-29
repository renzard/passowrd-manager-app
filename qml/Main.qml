// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import io.thp.pyotherside 1.5
import Qt.labs.settings 1.0

import "pages"
import "themes"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "password-manager.yourdomain"
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    // Storage path is computed inside the Python backend itself now
    // (see backend/vault_backend.py::_default_vault_path) rather than
    // depending on QML's MainView.dataLocation.
    property bool unlocked: false

    // Persisted app theme (dark/light mode and the themes page both use this)
    Settings {
        id: appSettings
        property string themeName: "Lomiri.Components.Themes.Ambiance"
        property string displayName: ""
    }
    property alias displayName: appSettings.displayName
    property string themeName: appSettings.themeName

    // "Bitwarden" is not a Lomiri theme of its own: it is Suru Dark plus custom
    // colours (themes/BitwardenColors.qml) and a Bitwarden-style vault layout.
    readonly property string bitwardenThemeName: "Bitwarden"
    readonly property bool bitwarden: themeName === bitwardenThemeName
    // "Aegis" is likewise Suru Dark plus themes/AegisColors.qml and its own home screen.
    readonly property string aegisThemeName: "Aegis"
    readonly property bool aegis: themeName === aegisThemeName
    theme.name: (bitwarden || aegis) ? "Lomiri.Components.Themes.SuruDark" : themeName
    BitwardenColors { id: bwColors }
    AegisColors { id: aegisColors }

    // Navy backdrop behind all pages when the Bitwarden theme is active
    Rectangle {
        z: -1
        anchors.fill: parent
        opacity: root.bitwarden ? 1 : 0
        visible: opacity > 0
        color: bwColors.background
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    // Near-black backdrop for the Aegis theme
    Rectangle {
        z: -1
        anchors.fill: parent
        opacity: root.aegis ? 1 : 0
        visible: opacity > 0
        color: aegisColors.background
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    function setTheme(name) {
        appSettings.themeName = name;
    }

    Python {
        id: python
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../backend"));
            importModule("vault_backend", function () {
                python.call("vault_backend.vault_exists", [], function (exists) {
                    if (pageStack.unlockPage) {
                        pageStack.unlockPage.vaultExists = exists;
                    }
                });
            });
        }

        onError: {
            console.log("Python error: " + traceback);
        }

        Component.onDestruction: {
            python.call("vault_backend.lock_vault", []);
        }
    }

    // Central place to react to backend signals regardless of which page
    // triggered the call, since PyOtherSide broadcasts globally.
    Connections {
        target: python
        onReceived: {
            if (data[0] === "vault-unlocked") {
                root.unlocked = true;
                pageStack.clear();
                pageStack.push(Qt.resolvedUrl("pages/VaultPage.qml"), { python: python, mainView: root });
            } else if (data[0] === "vault-locked") {
                root.unlocked = false;
                pageStack.clear();
                pageStack.unlockPage = pageStack.push(Qt.resolvedUrl("pages/UnlockPage.qml"),
                                { python: python, vaultExists: true });
            }
        }
    }

    PageStack {
        id: pageStack
        property var unlockPage: null
        Component.onCompleted: {
            unlockPage = push(Qt.resolvedUrl("pages/UnlockPage.qml"), { python: python });
        }
    }
}
