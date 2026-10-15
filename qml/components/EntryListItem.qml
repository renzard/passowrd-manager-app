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
    property string iconPath: ""
    property bool showIcon: false
    property bool favorite: false

    signal entryClicked(string uuid)
    signal copyUsername(string uuid)
    signal copyPassword(string uuid)
    signal toggleFavorite(string uuid, bool pinned)
    signal entryLongPressed(string uuid, string title, string username)

    // Tap = open/edit the entry, press-and-hold = quick-copy dialog.
    onClicked: entryClicked(uuid)
    onPressAndHold: entryLongPressed(uuid, title, username)

    SiteIcon {
        id: siteIcon
        visible: item.showIcon
        anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
        width: units.gu(4.5); height: width
        iconPath: item.iconPath
        letter: item.title.length > 0 ? item.title.charAt(0).toUpperCase() : "?"
        tileColor: theme.palette.normal.base
        letterColor: theme.palette.normal.baseText
    }

    Column {
        anchors {
            left: item.showIcon ? siteIcon.right : parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: item.showIcon ? units.gu(1.5) : units.gu(2)
            rightMargin: item.favorite ? units.gu(5) : units.gu(2)
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

    Icon {
        visible: item.favorite
        anchors { right: parent.right; rightMargin: units.gu(1.8); verticalCenter: parent.verticalCenter }
        width: units.gu(2.2); height: width
        name: "starred"
        color: "#f5b301"
    }

    trailingActions: ListItemActions {
        actions: [
            Action {
                iconName: item.favorite ? "non-starred" : "starred"
                text: item.favorite ? i18n.tr("Unpin") : i18n.tr("Pin to top")
                onTriggered: item.toggleFavorite(item.uuid, !item.favorite)
            },
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
