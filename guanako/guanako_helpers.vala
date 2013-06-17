/*
 * guanako/guanako_helpers.vala
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
using Vala;

namespace Guanako {
    public static inline string? get_vapi_path (string pkg, string[]? directories = null) {
        return get_file_path (pkg, ".vapi", directories);
    }

    public static inline string? get_deps_path (string pkg, string[]? directories = null) {
        return get_file_path (pkg, ".deps", directories);
    }

    private static string? get_file_path (string pkg, string ext, string[]? directories) {
        if  (directories != null)
            //TRANSLATORS: E.g.: Checking .vapi dir: /usr/share/vala/vapi
            foreach (var dir in directories) {
                debug_msg ("Checking %s dir: %s\n", ext, dir);
                var filename = Path.build_path (Path.DIR_SEPARATOR_S, dir, pkg + ext);
                if (FileUtils.test (filename, FileTest.EXISTS))
                    return filename;
            }
        foreach (var dir in get_vapi_dirs()) {
            debug_msg ("Checking %s dir: %s\n", ext, dir);
            var filename = Path.build_path (Path.DIR_SEPARATOR_S, dir, pkg + ext);
            if (FileUtils.test (filename, FileTest.EXISTS))
                return filename;
        }
        return null;
    }

    public static string[] get_vapi_dirs() {
        var dirs = new string[0];
        foreach (var dir in Environment.get_system_data_dirs())
            dirs += Path.build_path (Path.DIR_SEPARATOR_S, dir, "vala/vapi");
        foreach (var dir in Environment.get_system_data_dirs())
            dirs += Path.build_path (Path.DIR_SEPARATOR_S, dir,
                                     "vala-" + Config.VALA_VERSION,
                                     "vapi");
        return dirs;
    }

    /**
     * Get Vala packages from filenames and sort them.
     */
    public static GLib.List<string>? get_available_packages() {
        GLib.List<string> list = null;
        foreach (string path in get_vapi_dirs()) {
            if (!FileUtils.test (path, FileTest.IS_DIR))
                continue;
            debug_msg ("Checking %s dir: %s\n", ".vapi", path);
            try {
                var enumerator = File.new_for_path (path).enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    var filename = file_info.get_name();
                    if (filename.has_suffix (".vapi"))
                        list.insert_sorted (filename.substring (0, filename.length - 5), strcmp);
                }
            } catch (GLib.Error e) {
                stdout.printf (_("Could not update vapi files: %s\n"), e.message);
                return null;
            }
        }
        return list;
    }

     //Helper function for checking whether a given source location is inside a SourceReference
    public static bool before_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.begin.line > source_line)
            return true;
        if (reference.begin.line == source_line && reference.begin.column > source_col)
            return true;
        return false;
    }

    public static bool after_source_ref (SourceFile source_file,
                                         int source_line,
                                         int source_col,
                                         SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.end.line < source_line)
            return true;
        if (reference.end.line == source_line && reference.end.column < source_col)
            return true;
        return false;
    }

    public static bool inside_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.begin.line > source_line || reference.end.line < source_line)
            return false;
        if (reference.begin.line == source_line && reference.begin.column > source_col)
            return false;
        if (reference.end.line == source_line && reference.end.column < source_col)
            return false;
        return true;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
