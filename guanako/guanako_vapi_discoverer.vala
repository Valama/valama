/*
 * guanako/guanako_vapi_discoverer.vala
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

namespace Guanako {
    public static string? discover_vapi_file (string needle_namespace) {
        foreach (string vapipath in get_vapi_dirs()) {
            var directory = File.new_for_path (vapipath);

            try {
                var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    if (file_info.get_name().has_suffix (".vapi")) {
                        var file = File.new_for_path (vapipath + file_info.get_name());
                        var dis = new DataInputStream (file.read());
                        string line;
                        /*
                         * Read lines until end of file (null) is reached.
                         */
                        while ((line = dis.read_line (null)) != null)
                            if (line.contains ("namespace " + needle_namespace + " "))
                                return file_info.get_name().substring (0, file_info.get_name().length - 5);
                    }
                }
            } catch (GLib.IOError e) {
                errmsg (_("Could not read file: %s"), e.message);
            } catch (GLib.Error e) {
                errmsg (_("Could not operate on directory: %s"), e.message);
            }
        }
        return null;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
