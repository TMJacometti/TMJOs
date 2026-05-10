// TMJOs Tweaks — GNOME Shell extension that hides the Activities button.
//
// GJS (GNOME JavaScript), runs sandboxed inside gnome-shell. No
// network, no filesystem, no exec — only Main.* APIs.
//
// Code volume: ~4 functional lines. Audit window: 30 seconds.

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class TMJOsTweaksExtension extends Extension {
    enable() {
        const activities = Main.panel.statusArea.activities;
        if (activities) {
            this._previousVisible = activities.visible;
            activities.hide();
        }
    }

    disable() {
        const activities = Main.panel.statusArea.activities;
        if (activities && this._previousVisible !== undefined) {
            activities.visible = this._previousVisible;
            this._previousVisible = undefined;
        }
    }
}
