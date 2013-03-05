/*
 * src/ui/ui_elements_ext.vala
 * Copyright (C) 2012, 2013, Valama development team
 *
 * Valama is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Valama is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;

public abstract class UiElementExt : UiElement {
    public static ValamaProject vproject { get; set; }

    public UiElementExt() {
        vproject = (ValamaProject) project;
        notify["project"].connect (() => {
            vproject = (ValamaProject) project;
        });
        notify["vproject"].connect (() => {
            project = (RawValamaProject) vproject;
        });
    }

    /**
     * Show item in some {@link IdeModes} modes.
     */
    //TODO: Add workaround for gdl < 3.5.5 to dock gdl item after hiding.
    public void mode_to_show (IdeModes mode) {
        vproject.notify["idemode"].connect(() => {
            if (dock_item != null) {
                if ((vproject.idemode & mode) != 0) {
                    if (!dock_item.visible) {
                        dock_item.show_item();
                        dock_item.show_all();
                    }
                } else if (dock_item.visible)
                    dock_item.hide_item();
            }
        });
    }
}

// vim: set ai ts=4 sts=4 et sw=4
