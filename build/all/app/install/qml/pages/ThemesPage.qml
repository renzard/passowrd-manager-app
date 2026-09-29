import QtQuick 2.7
import Lomiri.Components 1.3
import "../components"

Page {
    id: themesPage
    objectName: "themesPage"

    // Smooth fade + slide when this page opens or is returned to
    opacity: transition.progress
    transform: Translate { x: transition.offset }
    PageTransition { id: transition }

    property var mainView

    // Add more entries here to offer more themes.
    readonly property var themes: [
        { label: "Ambiance (light)", name: "Lomiri.Components.Themes.Ambiance" },
        { label: "Suru Dark",        name: "Lomiri.Components.Themes.SuruDark" },
        { label: "Bitwarden",        name: "Bitwarden" }
    ]

    header: PageHeader {
        id: themesHeader
        title: i18n.tr("Themes")
    }

    Column {
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
