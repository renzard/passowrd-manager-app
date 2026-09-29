import QtQuick 2.7
import Lomiri.Components 1.3

// Modern Lomiri ListItem (not the deprecated ListItems.Standard) so we get
// swipe-to-reveal trailingActions for the quick-copy shortcuts.
ListItem {
    id: item
    property string uuid
    property string title
    property string username
    property string category

    signal entryClicked(string uuid)
    signal copyUsername(string uuid)
    signal copyPassword(string uuid)
    signal entryLongPressed(string uuid, string title, string username)

    // Tap = open/edit the entry, press-and-hold = quick-copy dialog.
    onClicked: entryClicked(uuid)
    onPressAndHold: entryLongPressed(uuid, title, username)

    Column {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
        }
        Label {
            text: item.title
            fontSize: "medium"
            elide: Text.ElideRight
        }
        Label {
            text: item.username + (item.category ? "  \u00B7  " + item.category : "")
            fontSize: "small"
            color: theme.palette.normal.backgroundSecondaryText
            elide: Text.ElideRight
        }
    }

    trailingActions: ListItemActions {
        actions: [
            Action {
                iconName: "edit-copy"
                text: i18n.tr("Copy username")
                onTriggered: item.copyUsername(item.uuid)
            },
            Action {
                iconName: "edit-paste"
                text: i18n.tr("Copy password")
                onTriggered: item.copyPassword(item.uuid)
            }
        ]
    }
}
