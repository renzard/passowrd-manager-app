import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"

Page {
    id: generatorPage
    objectName: "generatorPage"

    property var python
    // When opened from AddEditEntryPage to pick a password for the field.
    property bool pickMode: false
    signal passwordPicked(string password)

    property int pwLength: 16
    property bool useUpper: true
    property bool useLower: true
    property bool useDigits: true
    property bool useSymbols: true
    property string generated: ""

    header: PageHeader {
        id: pageHeader
        title: i18n.tr("Password Generator")
    }

    SelfClearingClipboard { id: clipboard }

    Connections {
        target: python
        onReceived: {
            if (data[0] === "password-generated") {
                generated = data[1];
            }
        }
    }

    function regenerate() {
        python.call("vault_backend.make_password",
                     [pwLength, useUpper, useLower, useDigits, useSymbols]);
    }

    Component.onCompleted: regenerate()

    Column {
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; margins: units.gu(2) }
        spacing: units.gu(2)

        Rectangle {
            width: parent.width
            height: units.gu(6)
            color: theme.palette.normal.background
            border.color: theme.palette.normal.base
            radius: units.gu(0.5)
            Label {
                anchors.centerIn: parent
                text: generated
                fontSize: "large"
                font.family: "Ubuntu Mono"
            }
        }

        Row {
            width: parent.width
            spacing: units.gu(1)
            Button {
                width: (parent.width - units.gu(1)) / 2
                text: i18n.tr("Regenerate")
                onClicked: regenerate()
            }
            Button {
                width: (parent.width - units.gu(1)) / 2
                text: i18n.tr("Copy")
                onClicked: clipboard.copySecret(generated)
            }
        }

        Label { text: i18n.tr("Length") + ": " + pwLength }
        Slider {
            width: parent.width
            minimumValue: 8
            maximumValue: 64
            value: pwLength
            live: true
            onValueChanged: { pwLength = Math.round(value); regenerate(); }
        }

        Column {
            width: parent.width
            spacing: units.gu(1)

            Row {
                spacing: units.gu(1)
                CheckBox { id: upperBox; checked: useUpper; onCheckedChanged: { useUpper = checked; regenerate(); } }
                Label { text: i18n.tr("Uppercase (A-Z)"); anchors.verticalCenter: upperBox.verticalCenter }
            }
            Row {
                spacing: units.gu(1)
                CheckBox { id: lowerBox; checked: useLower; onCheckedChanged: { useLower = checked; regenerate(); } }
                Label { text: i18n.tr("Lowercase (a-z)"); anchors.verticalCenter: lowerBox.verticalCenter }
            }
            Row {
                spacing: units.gu(1)
                CheckBox { id: digitsBox; checked: useDigits; onCheckedChanged: { useDigits = checked; regenerate(); } }
                Label { text: i18n.tr("Numbers (0-9)"); anchors.verticalCenter: digitsBox.verticalCenter }
            }
            Row {
                spacing: units.gu(1)
                CheckBox { id: symbolsBox; checked: useSymbols; onCheckedChanged: { useSymbols = checked; regenerate(); } }
                Label { text: i18n.tr("Symbols (!@#$...)"); anchors.verticalCenter: symbolsBox.verticalCenter }
            }
        }

        Button {
            width: parent.width
            visible: pickMode
            color: theme.palette.normal.positive
            text: i18n.tr("Use this password")
            onClicked: passwordPicked(generated)
        }
    }
}
