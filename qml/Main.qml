// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import io.thp.pyotherside 1.5

import "pages"

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
                pageStack.push(Qt.resolvedUrl("pages/VaultPage.qml"), { python: python });
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
