/*
 * guanako/guanako_frankenstein.vala
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
using Vala;

namespace Guanako {
    public class FrankenStein {
        public FrankenStein() {
            Bus.own_name (BusType.SESSION, "app.valama.frankenstein", BusNameOwnerFlags.NONE,
                  on_bus_aquired,
                  () => {},
                  () => stderr.printf ("Could not aquire name\n"));
        }

        void on_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object ("/app/valama/frankenstein", new FrankenDBUS (this));
            } catch (IOError e) {
                stderr.printf ("Could not register service\n");
            }
        }

        [DBus (name = "app.valama.frankenstein")]
        class FrankenDBUS : Object {
            public FrankenDBUS (FrankenStein parent) {
                this.parent = parent;
            }
            FrankenStein parent;
            public void timer_finished (int timer_id, double time) {
                parent.timer_finished (parent.frankentimers[timer_id], time);
            }
        }

        public struct FrankenTimer {
            public SourceFile file;
            public int start_line;
            public int end_line;
            public bool active;
        }

        public Gee.ArrayList<FrankenTimer?> frankentimers = new Gee.ArrayList<FrankenTimer?>();
        public signal void timer_finished (FrankenTimer timer, double time);

        public string frankensteinify_sourcefile (SourceFile file) {
            string[] lines = file.content.split ("\n");
            int cnt = 0;
            foreach (FrankenTimer ftime in frankentimers) {
                lines[ftime.start_line - 1] = @"var frankentimer_$(cnt.to_string()) = new GLib.Timer(); frankentimer_$(cnt.to_string()).start(); " + lines[ftime.start_line - 1];
                lines[ftime.end_line - 1] = @"frankentimer_callback($(cnt.to_string()), frankentimer_$(cnt.to_string()).elapsed());" + lines[ftime.end_line - 1];
                cnt++;
            }
            string ret = "";
            foreach (string line in lines)
                ret += line + "\n";
            ret += "[DBus (name = 'app.valama.frankenstein')]\n"
                + "interface FrankenDBUS : Object {\n"
                + "    public abstract void timer_finished (int timer_id, double time) throws IOError;\n"
                + "}\n"
                + "static FrankenDBUS frankenstein_client = null;\n"
                + "static void frankentimer_callback (int timer_id, double time) {\n"
                + "    if (frankenstein_client == null)\n"
                + "        frankenstein_client = Bus.get_proxy_sync (BusType.SESSION, 'app.valama.frankenstein', '/app/valama/frankenstein');\n"
                + "    frankenstein_client.timer_finished (timer_id, time);\n"
                + "}\n";
            return ret;
        }
    }

}

// vim: set ai ts=4 sts=4 et sw=4
