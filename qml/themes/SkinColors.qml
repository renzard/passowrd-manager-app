// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3

// One colour/shape set for the shared themed controls (ThemedButton, ThemedField,
// ThemedRow...). Set `skin` to "onyx" or "emerald".
QtObject {
    id: skinColors
    // "onyx", "emerald", "aegis" or "bitwarden"
    property string skin: "onyx"

    property QtObject onyxC: OnyxColors {}
    property QtObject emeraldC: EmeraldColors {}
    property QtObject aegisC: AegisColors {}
    property QtObject bitwardenC: BitwardenColors {}

    // pick(onyx, emerald, aegis, bitwarden)
    function pick(o, e, a, b) {
        return skin === "bitwarden" ? b : skin === "aegis" ? a : skin === "emerald" ? e : o;
    }

    readonly property color background:    pick(onyxC.background, emeraldC.background, aegisC.background, bitwardenC.background)
    readonly property color cardTop:       pick(onyxC.cardTop, emeraldC.card, aegisC.card, bitwardenC.card)
    readonly property color cardBottom:    pick(onyxC.cardBottom, emeraldC.card, aegisC.card, bitwardenC.card)
    readonly property color cardPressed:   pick(onyxC.cardPressed, emeraldC.cardPressed, "#1a1c2b", bitwardenC.nav)
    readonly property color field:         pick(onyxC.pill, emeraldC.field, aegisC.field, bitwardenC.field)
    readonly property color tile:          pick(onyxC.tile, emeraldC.tile, "#1b1d30", bitwardenC.navSelected)
    readonly property color track:         pick(onyxC.track, emeraldC.track, "#1d2036", bitwardenC.nav)
    readonly property color border:        pick(onyxC.border, emeraldC.border, aegisC.border, Qt.rgba(1, 1, 1, 0.09))
    readonly property color text:          pick(onyxC.text, emeraldC.text, aegisC.text, bitwardenC.text)
    readonly property color secondaryText: pick(onyxC.secondaryText, emeraldC.secondaryText, aegisC.secondaryText, bitwardenC.secondaryText)
    readonly property color accent:        pick(onyxC.accent, emeraldC.accent, aegisC.accent, bitwardenC.accent)
    // top colour of the primary-button gradient (Aegis only; flat for the others)
    readonly property color accentTop:     skin === "aegis" ? aegisC.accentSoft : accent
    readonly property color accentText:    pick(onyxC.accentText, emeraldC.accentText, aegisC.accentText, bitwardenC.accentText)
    readonly property color accentPressed: pick("#d0d0d2", "#36c28a", "#5849e0", "#4a93e0")
    readonly property color focusBorder:   pick(onyxC.secondaryText, emeraldC.accent, aegisC.accent, bitwardenC.accent)
    readonly property color pressedBorder: pick(onyxC.border, emeraldC.accent, aegisC.accent, Qt.rgba(1, 1, 1, 0.09))
    readonly property color passwordText:  pick(onyxC.text, emeraldC.accent, aegisC.accentSoft, bitwardenC.accent)

    readonly property real cardRadius: units.gu(pick(2.4, 1.8, 1.5, 2))
    readonly property real bigRadius:  units.gu(pick(3, 1.8, 1.5, 2))
    // Onyx and Bitwarden use fully round (pill) buttons and fields
    function pillRadius(h) {
        return (skin === "onyx" || skin === "bitwarden") ? h / 2 : units.gu(skin === "aegis" ? 1.5 : 1.8);
    }
}
