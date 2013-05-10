/*
 * src/common/args.vala
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
    public string? syntaxfile = null;
    public string? templatesdir = null;
    public string? buildsystemsdir = null;
    public int debuglevel = 0;
    public bool forceold = false;
    public string? layoutfile = null;
    public bool reset_layout = false;
    [CCode (array_length = false, array_null_terminated = true)]
    public string[]? projectfiles = null;

    private const OptionEntry[] options = {
        {"version", 'v', 0, OptionArg.NONE, ref version, N_("Display version number."), null},
        {"syntax", 0, 0, OptionArg.FILENAME, ref syntaxfile, N_("Guanako syntax file."), N_("FILE")},
        {"templates", 0, 0, OptionArg.FILENAME, ref templatesdir, N_("Templates directory."),
        // TRANSLATORS: Uppercase for variables in command line options.
                                                            N_("DIRECTORY")},
        {"buildsystems", 0, 0, OptionArg.FILENAME, ref buildsystemsdir, N_("Build systems directory."), N_("DIRECTORY")},
        {"debug", 'd', OptionFlags.OPTIONAL_ARG, OptionArg.CALLBACK, (void*) debuglevel_parse, N_("Output debug information."), N_("[DEBUGLEVEL]")},
        {"force-old", 0, 0, OptionArg.NONE, ref forceold, N_("Force loading of possibly incompatible template or project files."), null},
        {"layout", 0, 0, OptionArg.FILENAME, ref layoutfile, N_("Path to layout file."), N_("FILE")},
        {"reset-layout", 0, 0, OptionArg.NONE, ref reset_layout, N_("Load default layout."), null},
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
            errmsg (_("Error: %s\n"), e.message);
            errmsg (_("Run '%s --help' to see a full list of available command line options.\n"), args[0]);
            return 1;
        }

        if (version) {
            msg ("%s: %s\n", Config.PACKAGE_NAME, Config.PACKAGE_VERSION);
            ret = -1;
        }

        return ret;
    }

    internal bool debuglevel_parse (string name, string? val, ref OptionError error) throws OptionError {
        if (val == null) {
            debuglevel = 1;
            return true;
        }
        var re = /^[+]?[0-9]+$/;
        if (!re.match (val, 0, null))
            throw new OptionError.BAD_VALUE (_("'%s' not a positive number"), val);
        debuglevel = int.parse (val);
        return true;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
