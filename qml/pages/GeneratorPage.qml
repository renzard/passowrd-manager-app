import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import "../themes"

Page {
    id: generatorPage
    objectName: "generatorPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var python
    property var mainView
    readonly property string skin: mainView ? (mainView.onyx ? "onyx" : mainView.emerald ? "emerald" : mainView.aegis ? "aegis" : mainView.bitwarden ? "bitwarden" : "") : ""
    readonly property bool themed: skin !== ""
    SkinColors { id: sc; skin: generatorPage.skin === "" ? "onyx" : generatorPage.skin }

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
        StyleHints {
            backgroundColor: generatorPage.themed ? sc.background : theme.palette.normal.background
            foregroundColor: generatorPage.themed ? sc.text : theme.palette.normal.backgroundText
            dividerColor: generatorPage.themed ? "transparent" : theme.palette.normal.base
        }
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

    function optionValue(key) {
        return key === "upper" ? useUpper : key === "lower" ? useLower
             : key === "digits" ? useDigits : useSymbols;
    }
    function toggleOption(key) {
        if (key === "upper") useUpper = !useUpper;
        else if (key === "lower") useLower = !useLower;
        else if (key === "digits") useDigits = !useDigits;
        else useSymbols = !useSymbols;
        regenerate();
    }

    // ---------------------------------------------------------------
    // themed layout (Onyx / Emerald)
    // ---------------------------------------------------------------
    Flickable {
        id: themedFlick
        visible: generatorPage.themed
        anchors { left: parent.left; right: parent.right; top: pageHeader.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: themedColumn.height + units.gu(3)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: themedColumn
            x: units.gu(2)
            width: parent.width - units.gu(4)
            spacing: units.gu(1.8)

            Item { width: 1; height: units.gu(0.2) }

            // Generated password
            Rectangle {
                width: parent.width
                height: Math.max(units.gu(13), pwLabel.paintedHeight + units.gu(7))
                radius: sc.bigRadius
                border.width: units.dp(1); border.color: sc.border
                gradient: Gradient {
                    GradientStop { position: 0; color: sc.cardTop }
                    GradientStop { position: 1; color: sc.cardBottom }
                }
                Label {
                    anchors { top: parent.top; topMargin: units.gu(1.8); horizontalCenter: parent.horizontalCenter }
                    text: i18n.tr("Generated password")
                    fontSize: "x-small"; color: sc.secondaryText
                }
                Label {
                    id: pwLabel
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: units.gu(2); rightMargin: units.gu(2); verticalCenterOffset: units.gu(1) }
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    text: generated
                    fontSize: "large"
                    font.family: "Ubuntu Mono"
                    color: sc.passwordText
                }
            }

            Row {
                width: parent.width
                spacing: units.gu(1.2)
                ThemedButton {
                    skin: generatorPage.skin
                    width: (parent.width - units.gu(1.2)) / 2
                    text: i18n.tr("Regenerate")
                    iconName: "reload"
                    onClicked: regenerate()
                }
                ThemedButton {
                    skin: generatorPage.skin
                    width: (parent.width - units.gu(1.2)) / 2
                    primary: true
                    text: i18n.tr("Copy")
                    iconName: "edit-copy"
                    onClicked: clipboard.copySecret(generated)
                }
            }

            // Length
            Rectangle {
                width: parent.width
                height: units.gu(11)
                radius: sc.bigRadius
                border.width: units.dp(1); border.color: sc.border
                gradient: Gradient {
                    GradientStop { position: 0; color: sc.cardTop }
                    GradientStop { position: 1; color: sc.cardBottom }
                }
                Label {
                    anchors { left: parent.left; leftMargin: units.gu(2.2); top: parent.top; topMargin: units.gu(1.8) }
                    text: i18n.tr("Length")
                    font.bold: true; fontSize: "medium"; color: sc.text
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: units.gu(2); top: parent.top; topMargin: units.gu(1.4) }
                    width: units.gu(5.4); height: units.gu(3.4); radius: height / 2
                    color: sc.tile
                    Label { anchors.centerIn: parent; text: pwLength; font.bold: true; fontSize: "small"; color: sc.text }
                }
                ThemedSlider {
                    skin: generatorPage.skin
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: units.gu(2.2); rightMargin: units.gu(2.2); bottomMargin: units.gu(1.6) }
                    minimumValue: 8
                    maximumValue: 64
                    value: pwLength
                    onMoved: { pwLength = newValue; regenerate(); }
                }
            }

            // Character sets
            Rectangle {
                width: parent.width
                height: optionsColumn.height
                radius: sc.bigRadius
                border.width: units.dp(1); border.color: sc.border
                gradient: Gradient {
                    GradientStop { position: 0; color: sc.cardTop }
                    GradientStop { position: 1; color: sc.cardBottom }
                }
                Column {
                    id: optionsColumn
                    width: parent.width
                    Repeater {
                        model: [
                            { key: "upper",   label: i18n.tr("Uppercase (A-Z)") },
                            { key: "lower",   label: i18n.tr("Lowercase (a-z)") },
                            { key: "digits",  label: i18n.tr("Numbers (0-9)") },
                            { key: "symbols", label: i18n.tr("Symbols (!@#$...)") }
                        ]
                        delegate: Item {
                            width: optionsColumn.width
                            height: units.gu(7)
                            Label {
                                anchors { left: parent.left; leftMargin: units.gu(2.2); verticalCenter: parent.verticalCenter }
                                text: modelData.label
                                fontSize: "small"; color: sc.text
                            }
                            ThemedSwitch {
                                skin: generatorPage.skin
                                anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                                checked: generatorPage.optionValue(modelData.key)
                                onClicked: generatorPage.toggleOption(modelData.key)
                            }
                            Rectangle {
                                visible: index < 3
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                          leftMargin: units.gu(2.2); rightMargin: units.gu(2.2) }
                                height: units.dp(1); color: sc.border
                            }
                        }
                    }
                }
            }

            ThemedButton {
                    skin: generatorPage.skin
                width: parent.width
                visible: pickMode
                primary: true
                text: i18n.tr("Use this password")
                iconName: "tick"
                onClicked: passwordPicked(generated)
            }
        }
    }

    Column {
        visible: !generatorPage.themed
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
