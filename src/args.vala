/*
 * src/args.vala
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

using GLib;

namespace Args {
    public bool version = false;
    [CCode (array_length = false, array_null_terminated = true)]
    public string[]? projectfiles = null;

    private const OptionEntry[] options = {
        {"version", 'v', 0, OptionArg.NONE, ref version, N_("Display version number."), null},
        {"", 0, 0, OptionArg.FILENAME_ARRAY, ref projectfiles, N_("Load project from file."), N_("[FILE...]")},
        {null}
    };

    public int parse (string[] args) {
        int ret = 0;

        var opt_context = new OptionContext (_("- Valama: next generation Vala IDE"));
        opt_context.set_help_enabled (true);
        opt_context.add_main_entries (options, null);
        try {
            opt_context.parse (ref args);
        } catch (OptionError e) {
            stderr.printf (_("Error: %s\n"), e.message);
            stderr.printf (_("Run '%s --help' to see a full list of available command line options.\n"), args[0]);
            return 1;
        }

        if (version) {
            stdout.printf ("%s: %s\n", Config.PACKAGE_NAME, Config.PACKAGE_VERSION);
            ret = -1;
        }

        return ret;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
