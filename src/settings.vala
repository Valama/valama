/*
 * src/settings.vala
 * Copyright (C) 2013, Valama development team
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

class ValamaSettings {

    public ValamaSettings() {
        settings = new Settings ("apps.valama");
    }
    Settings settings;

    public int window_size_x {
        get { return settings.get_int ("window-size-x"); }
        set { settings.set_int ("window-size-x", value); }
    }
    public int window_size_y {
        get { return settings.get_int ("window-size-y"); }
        set { settings.set_int ("window-size-y", value); }
    }

}

// vim: set ai ts=4 sts=4 et sw=4
