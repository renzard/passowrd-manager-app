// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Text field that renders in the Onyx / Emerald style when `skin` is set
// ("onyx" or "emerald") and as the normal Lomiri TextField when it is empty
// (so other themes are untouched).
// Set multiline: true for a notes-style area.
Item {
    id: field
    property string skin: ""
    readonly property bool themed: skin !== ""
    property bool multiline: false
    property string text: ""
    property string placeholderText: ""
    property int echoMode: TextInput.Normal
    property int inputMethodHints: Qt.ImhNone

    implicitHeight: themed ? (multiline ? units.gu(14) : units.gu(5.6)) : (multiline ? units.gu(10) : plain.height)
    height: implicitHeight

    SkinColors { id: c; skin: field.skin === "" ? "onyx" : field.skin }

    // ---- other themes ---------------------------------------------------
    TextField {
        id: plain
        visible: !field.themed && !field.multiline
        width: parent.width
        text: field.text
        onTextChanged: field.text = text
        placeholderText: field.placeholderText
        echoMode: field.echoMode
        inputMethodHints: field.inputMethodHints
    }
    TextArea {
        id: plainArea
        visible: !field.themed && field.multiline
        width: parent.width; height: parent.height
        text: field.text
        onTextChanged: field.text = text
    }

    // ---- Onyx -----------------------------------------------------------
    Rectangle {
        visible: field.themed
        anchors.fill: parent
        radius: field.multiline ? c.cardRadius : c.pillRadius(height)
        color: c.field
        border.width: units.dp(1)
        border.color: (singleInput.activeFocus || multiInput.activeFocus) ? c.focusBorder : c.border
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Item {
            anchors { fill: parent; leftMargin: units.gu(2.2); rightMargin: units.gu(2.2)
                      topMargin: field.multiline ? units.gu(1.6) : 0; bottomMargin: field.multiline ? units.gu(1.6) : 0 }
            clip: true

            Label {
                visible: (field.multiline ? multiInput.text : singleInput.text).length === 0
                         && !singleInput.inputMethodComposing
                anchors.verticalCenter: field.multiline ? undefined : parent.verticalCenter
                width: parent.width
                text: field.placeholderText
                fontSize: "small"; color: c.secondaryText
                elide: Text.ElideRight
            }
            TextInput {
                id: singleInput
                visible: !field.multiline
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                text: field.text
                onTextChanged: field.text = text
                color: c.text
                selectionColor: c.secondaryText
                selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9)
                echoMode: field.echoMode
                inputMethodHints: field.inputMethodHints
                clip: true
            }
            TextEdit {
                id: multiInput
                visible: field.multiline
                anchors.fill: parent
                text: field.text
                onTextChanged: field.text = text
                color: c.text
                selectionColor: c.secondaryText
                selectedTextColor: c.accentText
                font.pixelSize: units.gu(1.9)
                wrapMode: TextEdit.Wrap
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !singleInput.activeFocus && !multiInput.activeFocus
            onClicked: (field.multiline ? multiInput : singleInput).forceActiveFocus()
        }
    }
}
