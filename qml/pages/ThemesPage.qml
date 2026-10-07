import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"
import "../themes"

Page {
    id: themesPage
    objectName: "themesPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var mainView
    readonly property string skin: mainView ? (mainView.onyx ? "onyx" : mainView.emerald ? "emerald" : mainView.aegis ? "aegis" : mainView.bitwarden ? "bitwarden" : "") : ""
    readonly property bool themed: skin !== ""
    SkinColors { id: sc; skin: themesPage.skin === "" ? "onyx" : themesPage.skin }

    // Add more entries here to offer more themes.
    readonly property var themes: [
        { label: "Ambiance (light)", name: "Lomiri.Components.Themes.Ambiance" },
        { label: "Suru Dark",        name: "Lomiri.Components.Themes.SuruDark" },
        { label: "Bitwarden",        name: "Bitwarden" },
        { label: "Aegis",            name: "Aegis" },
        { label: "Emerald",          name: "Emerald" },
        { label: "Onyx",             name: "Onyx" }
    ]

    header: PageHeader {
        id: themesHeader
        title: i18n.tr("Themes")
        StyleHints {
            backgroundColor: themesPage.themed ? sc.background : theme.palette.normal.background
            foregroundColor: themesPage.themed ? sc.text : theme.palette.normal.backgroundText
            dividerColor: themesPage.themed ? "transparent" : theme.palette.normal.base
        }
    }

    // themed layout (Onyx / Emerald)
    Flickable {
        visible: themesPage.themed
        anchors { left: parent.left; right: parent.right; top: themesHeader.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: themedThemes.height + units.gu(4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: themedThemes
            x: units.gu(2)
            width: parent.width - units.gu(4)
            Item { width: 1; height: units.gu(0.4) }
            Repeater {
                model: themes
                delegate: ThemedRow {
                    skin: themesPage.skin
                    width: themedThemes.width
                    height: units.gu(7.6)
                    title: modelData.label
                    onClicked: mainView.setTheme(modelData.name)
                    Rectangle {
                        width: units.gu(3.4); height: width; radius: width / 2
                        readonly property bool current: mainView && mainView.themeName === modelData.name
                        color: current ? sc.accent : sc.tile
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2); height: width
                            name: "tick"
                            color: sc.accentText
                            visible: parent.current
                        }
                    }
                }
            }
        }
    }

    Column {
        visible: !themesPage.themed
        anchors { left: parent.left; right: parent.right; top: themesHeader.bottom }
        Repeater {
            model: themes
            delegate: ListItem {
                height: themeLayout.height + divider.height
                onClicked: mainView.setTheme(modelData.name)
                ListItemLayout {
                    id: themeLayout
                    title.text: modelData.label
                    Icon {
                        SlotsLayout.position: SlotsLayout.Trailing
                        width: units.gu(2); height: width
                        name: "tick"
                        visible: mainView && mainView.themeName === modelData.name
                    }
                }
            }
        }
    }
}
