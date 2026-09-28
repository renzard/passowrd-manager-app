import QtQuick 2.7

/*
 * SelfClearingClipboard
 * ----------------------
 * Ubuntu Touch's QtQuick does not expose a `Clipboard` singleton, so the
 * standard workaround is a hidden, non-visible TextEdit: select its text
 * and call copy()/cut() to push it through the system clipboard.
 *
 * copySecret(text) copies `text`, then after `clearAfterMs` overwrites the
 * clipboard with an empty string -- but ONLY if the clipboard still holds
 * what we put there (so we don't clobber something the user copied from
 * elsewhere in the meantime).
 */
Item {
    id: root
    property int clearAfterMs: 15000
    signal cleared()

    TextEdit {
        id: hiddenEditor
        visible: false
        // Keep it fully out of layout/accessibility trees.
        width: 0
        height: 0
    }

    Timer {
        id: clearTimer
        interval: root.clearAfterMs
        repeat: false
        onTriggered: {
            // Pull whatever is CURRENTLY on the system clipboard back into
            // the hidden editor, so we only wipe it if it still matches
            // what we put there -- otherwise the user copied something
            // else in the meantime and we leave it alone.
            hiddenEditor.text = "";
            hiddenEditor.paste();
            if (hiddenEditor.text === root._lastCopied) {
                hiddenEditor.text = "";
                hiddenEditor.selectAll();
                hiddenEditor.copy();
                root.cleared();
            }
        }
    }

    property string _lastCopied: ""

    function copySecret(text) {
        _lastCopied = text;
        hiddenEditor.text = text;
        hiddenEditor.selectAll();
        hiddenEditor.copy();
        clearTimer.restart();
    }
}
