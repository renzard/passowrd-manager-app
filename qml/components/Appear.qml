// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7

/*
 * Staggered "appear" helper (fade + slide up + optional zoom).
 *
 * Usage inside the item that should animate:
 *
 *     opacity: ap.progress
 *     scale: ap.zoom
 *     transform: Translate { y: ap.offset }
 *     Appear { id: ap; delay: 120 }
 *
 * Bind `run` to a counter to replay the animation whenever it changes.
 */
Item {
    id: helper

    property int delay: 0
    property int duration: 480
    property real distance: units.gu(3)
    property real startScale: 1
    property int easing: Easing.OutCubic
    property int run: 0

    property real progress: 0
    readonly property real offset: (1 - progress) * distance
    readonly property real zoom: startScale + (1 - startScale) * progress

    visible: false
    width: 0; height: 0

    SequentialAnimation {
        id: anim
        PauseAnimation { duration: helper.delay }
        NumberAnimation {
            target: helper
            property: "progress"
            to: 1
            duration: helper.duration
            easing.type: helper.easing
        }
    }

    function replay() {
        anim.stop();
        progress = 0;
        anim.start();
    }

    onRunChanged: replay()
    Component.onCompleted: anim.start()
}
