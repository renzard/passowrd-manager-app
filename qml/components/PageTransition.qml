// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7

/*
 * Smooth page transition helper.
 *
 * Lomiri's PageStack switches pages instantly, so every page owns one of
 * these. Usage inside a Page:
 *
 *     opacity: transition.progress
 *     transform: Translate { x: transition.offset }
 *     PageTransition { id: transition }
 *
 * - When the page is created it fades in while sliding in from the right.
 * - When it becomes active again (the page above it was popped) it fades in
 *   while sliding back in from the left.
 */
Item {
    id: helper

    // The page this helper animates. Defaults to the parent Page.
    property Item page: parent

    // 0 = hidden / fully offset, 1 = settled in place
    property real progress: 1
    // 1 = enter from the right (push), -1 = enter from the left (pop back)
    property int direction: 1
    property real distance: units.gu(5)
    property int duration: 340

    // Horizontal offset to bind to a Translate transform on the page
    readonly property real offset: (1 - progress) * direction * distance

    property bool ready: false
    visible: false
    width: 0; height: 0

    NumberAnimation {
        id: animation
        target: helper
        property: "progress"
        from: 0; to: 1
        duration: helper.duration
        easing.type: Easing.OutCubic
    }

    function play(dir) {
        direction = dir;
        distance = (dir > 0) ? units.gu(5) : units.gu(3);
        animation.restart();
    }

    Component.onCompleted: {
        ready = true;
        play(1);
    }

    // Returning to this page after the one on top of it was popped
    Connections {
        target: helper.page
        onActiveChanged: {
            if (helper.ready && helper.page.active && !animation.running) {
                helper.play(-1);
            }
        }
    }
}
