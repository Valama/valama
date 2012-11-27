/**
 * src/common.vala
 * Copyright (C) 2012, Dominique Lasserre <lasserre.d@gmail.com>
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

public enum CopyRecursiveFlags {
    SKIP_ON_EXISTANCE,
    WARN_ON_OVERWRITE
}

/*
 * Wrapper function to copy files recursively.
 * All flags are passed to appropriate methods. Additionally if
 * CopyRecursiveFlags.SKIP_ON_EXISTANCE is set don't error files already
 * exists.
 *
 *TODO: Not implemented:
 * If CopyRecursiveFlags.WARN_ON_OVERWRITE is set show dialog to get user
 * confirmation (e.g. backup, overwrite, skip, cancel).
 */
public void copy_recursively (string dir_from, string dir_to,
                              CopyRecursiveFlags flags = CopyRecursiveFlags.SKIP_ON_EXISTANCE,
                              FileCopyFlags copy_flags = FileCopyFlags.NONE,
                              FileQueryInfoFlags query_flags = FileQueryInfoFlags.NONE,
                              Cancellable? cancellable = null) throws Error {

    var dest = File.new_for_path (dir_to);
    var from = File.new_for_path (dir_from);

    if (!from.query_exists())
        throw new IOError.NOT_FOUND ("Origin does not exist.");

    if (!dest.query_exists())
        dest.make_directory_with_parents();

    int_copy_recursively (from, dest, flags, copy_flags, query_flags, cancellable);
}

/*
 * Copy files recursively from one directory to a new directory.
 */
internal void int_copy_recursively (File file_from, File file_to,
                                 CopyRecursiveFlags flags,
                                 FileCopyFlags copy_flags,
                                 FileQueryInfoFlags query_flags,
                                 Cancellable? cancellable = null) throws Error {

    FileEnumerator enumerator = file_from.enumerate_children ("standard::*",
                                                              query_flags,
                                                              cancellable);
    FileInfo info = null;
    while (cancellable.is_cancelled() == false && ((info = enumerator.next_file (cancellable)) != null)) {
        if (info.get_file_type() == FileType.DIRECTORY) {
            var subdir_from = file_from.resolve_relative_path (info.get_name());
            var new_to_path = file_to.resolve_relative_path (info.get_name());

            if (!new_to_path.query_exists())
                new_to_path.make_directory (cancellable);
            int_copy_recursively (subdir_from, new_to_path, flags, copy_flags, query_flags, cancellable);

        } else {
            var file_from_copy = file_from.resolve_relative_path (info.get_name());
            var file_to_copy = file_to.resolve_relative_path (info.get_name());
#if DEBUG
            stdout.printf ("Copy from '%s' to '%s'.\n", file_from_copy.get_path(),
                                                        file_to_copy.get_path());
#endif

            if (CopyRecursiveFlags.SKIP_ON_EXISTANCE == flags && file_to_copy.query_exists())
                continue;
            file_from_copy.copy (file_to_copy, copy_flags, cancellable);
        }
    }

    if (cancellable.is_cancelled())
        throw new IOError.CANCELLED ("File copying cancelled.");
}
