/*
 * src/common/common.vala
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

/**
 * Flags to control FileTransfer class.
 */
[Flags]
public enum CopyRecursiveFlags {
    /**
     * Do not count and do not skip or warn on existing files.
     */
    NONE,
    /**
     * Skip if file already exists and count before transfer.
     */
    SKIP_EXISTENT,
    /**
     * Warn if file already exists and count before transfer.
     */
    WARN_OVERWRITE,
    /**
     * Don't count.
     */
    NO_COUNT
}

/**
 * Transfer class to easily copy or move files or file trees.
 * The byte_count_changed and num_count_changed signals provides an comfortable
 * interface to connect a progress bar.
 *
 * {@link CopyRecursiveFlags} can be used to control some features:
 *
 *   * skip if files already exists
 *   * warn if files already exists
 *
 * Both options can be used with or without a run before to calculate size of
 * transfer (and signal interface with percentage / counts).
 *
 * If size is counted a {@link GLib.IOError.NO_SPACE} Error is raised if not
 * enough space is available.
 *
 * Remember to use special {@link GLib.FileCopyFlags} or
 * {@link GLib.FileQueryInfoFlags} or {@link GLib.Cancellable}.
 *
 *
 * = Example =
 *
 * {{{
 * using GLib;
 *
 * public static int main (string[] args) {
 * 	Gtk.init (ref args);
 * 	window_main = new Window();
 * 	window_main.title = "Test progress bar";
 * 	window_main.window_position = WindowPosition.CENTER;;
 * 	window_main.destroy.connect (main_quit);
 *
 * 	var bar = new ProgressBar();
 * 	window_main.add (bar);
 *
 * 	bar.set_text ("Test progress");
 * 	bar.set_show_text (true);
 *
 * 	window_main.show_all();
 *
 * 	var ft = new FileTransfer ("/path/to/directory1",
 * 				"/path/to/directory2",
 * 				CopyRecursiveFlags.WARN_OVERWRITE);
 *
 * 	ft.byte_count_changed.connect (bar.set_fraction);
 * 	ft.warn_overwrite.connect ((from, to) => {
 * 		stdout.printf ("We have some time to relax.\n");
 * 		Thread.usleep (100000);
 * 		return false;
 * 	});
 * 	ft.num_count_changed.connect ((cur, tot) => {
 * 		bar.set_text (@"$cur/$tot");
 * 	});
 *
 * 	new Thread<void*>.try ("Copy file", (ThreadFunc<void*>) ft.move);
 * 	Gtk.main();
 *
 * 	return 0;
 * }
 * }}}
 *
 * {{{
 * valac --pkg glib-2.0 --pkg gtk+-3.0 --target-glib=2.32 FileTransferTest.vala
 * }}}
 *
 *
 *
 */
public class FileTransfer : Object {
    /**
     * File object to transfer (recursively).
     */
    public File f_from { get; private set; }
    /**
     * File object to transfer to (recursively).
     */
    public File f_to { get; private set; }
    /**
     * Flag for {@link CopyRecursiveFlags}.
     */
    public CopyRecursiveFlags rec_flag { get; set; }
    /**
     * Flag for {@link GLib.File.move} or {@link GLib.File.copy}.
     */
    public FileCopyFlags copy_flag { get; set; }
    /**
     * Flag for {@link GLib.FileInfo}.
     */
    public FileQueryInfoFlags query_flag  { get; set; }
    /**
     * Flag for {@link GLib.Cancellable}.
     */
    public Cancellable? cancellable { get; set; }
    /**
     * Enable to create base destination directory.
     */
    public bool create_dest { get; set; default = true; }
    /**
     * Flag for {@link RecursiveAction} to indicate which action to perform
     * on iterating over files.
     */
    private RecursiveAction action;
    /**
     * Size of transfers currently done.
     */
    private double current_size = 0;
    /**
     * Total size of transfers (also existing files).
     */
    private double total_size = 0;
    /**
     * Size of transfers to do.
     *
     * {@link total_size} without existing files.
     */
    private double size_to_trans = 0;
    /**
     * Number of total transfers (to do).
     */
    private int count_total = 0;
    /**
     * Free space available on filesystem to transfer.
     */
    private uint64 fs_free;
    /**
     * Number of transfers done.
     */
    private int count_current = 0;
    /**
     * Flag to indicate if counter is on on copy/move step.
     *
     * This is used to avoid tests for all {@link CopyRecursiveFlags}
     * combinations  count vs. no-count.
     */
    private bool counter_on = false;
    /**
     * Flag to indicate if recursive or non-recursive operation is to do.
     */
    private bool is_file = false;
    /**
     * Flag to indicate that operation performs on same filesystem.
     */
    private bool same_fs = false;

    /**
     * Flag to indicate which file transfer action to do.
     */
    private enum RecursiveAction {
        COPY,
        MOVE,
        COUNT
    }

    /**
     * Setup all flags.
     *
     * @param from Path to do action from (e.g. filename to copy).
     * @param to Path to do action to (e.g. where to copy file).
     * @param rec_flag Flag to control action to do.
     * @param copy_flag Copy and move behavior (e.g. to overwrite file or make a backup).
     * @param query_flag Follow symlinks or not.
     * @param cancellable Is cancellable.
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    public FileTransfer (string from, string to,
                              CopyRecursiveFlags rec_flag = CopyRecursiveFlags.NONE,
                              FileCopyFlags copy_flag = FileCopyFlags.NONE,
                              FileQueryInfoFlags query_flag = FileQueryInfoFlags.NONE,
                              Cancellable? cancellable = null) throws GLib.Error, GLib.IOError {
        f_from = File.new_for_path (from);
        f_to = File.new_for_path (to);
        this.rec_flag = rec_flag;
        this.copy_flag = copy_flag;
        this.query_flag = query_flag;
        this.cancellable = cancellable;

        if (!f_from.query_exists())
            throw new IOError.NOT_FOUND (_("No such file."));

        var filetype = f_from.query_file_type (query_flag, cancellable);
        var info = f_from.query_info ("id::*", query_flag, cancellable);

        var f_to_tmp = f_to;
        while (!f_to_tmp.query_exists()) {
            f_to_tmp = f_to_tmp.get_parent();
            if (f_to_tmp == null)  // this should never happen so no further checks below
                break;
        }
        var info_to = f_to_tmp.query_info ("*", query_flag, cancellable);

        if (info.get_attribute_as_string (FileAttribute.ID_FILESYSTEM) ==
            info_to.get_attribute_as_string (FileAttribute.ID_FILESYSTEM))
            same_fs = true;
        else {
            var fsinfo_to = f_to_tmp.query_filesystem_info (FileAttribute.FILESYSTEM_FREE, cancellable);
            fs_free = fsinfo_to.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
        }

        /* Set the no-recursion flag accordingly. */
        if (filetype == FileType.REGULAR ||
                (filetype == FileType.SYMBOLIC_LINK &&
                query_flag == FileQueryInfoFlags.NOFOLLOW_SYMLINKS)) {
            is_file = true;
            /*
             * If destination object already exists and is a directory, make
             * f_to to a child of it.
             */
            if (f_to.query_exists()) {
                if (info_to.get_file_type() == FileType.DIRECTORY)
                    f_to = f_to.resolve_relative_path (f_from.get_basename());
            }
        }
    }

    /**
     * Emit percentage of file transfer.
     *
     * @param percent_done Percentage of file transfer.
     */
    public signal void byte_count_changed (double percent_done);

    /**
     * Emit on change number of current transferred files (and total amount).
     *
     * @param cur Current transferred files.
     * @param tot Total of files to transfer.
     */
    public signal void num_count_changed (int cur, int tot);

    /**
     * Signal with both file names to indicate if file should be overwritten.
     * Return `true` to overwrite file. To skip return `false`.
     *
     * Emit on change.
     *
     * @param from_name Path of file where action comes from.
     * @param to_name Path of file where action should go to.
     */
    public signal bool warn_overwrite (string from_name, string to_name);

    /**
     * Calculate total size of transfers.
     *
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    //TODO: Provide public interface to provide information without doing
    //      anything?
    private void calc_size() throws GLib.Error, GLib.IOError {
        if (CopyRecursiveFlags.SKIP_EXISTENT == rec_flag ||
                CopyRecursiveFlags.WARN_OVERWRITE == rec_flag) {
            counter_on = true;  // use this boolean to name counter flags only here
            action = RecursiveAction.COUNT;
            if (is_file) {
                total_size = (double) f_from.query_info ("standard::*", query_flag, cancellable).get_size();
                count_total = 1;
                transfer_file (f_from, f_to);
            } else
                do_recursively (f_from, f_to);
            current_size = total_size - size_to_trans;
            num_count_changed (count_current, count_total);
        }
        /* Check if enough free space is available on filesystem. */
        if (!same_fs && fs_free <= size_to_trans)
            throw new GLib.IOError.NO_SPACE (_("Not enough space available: %lld < %lld"),
                                             fs_free, (uint64) size_to_trans);
    }

    /**
     * Call the transfer methods properly, calculate before transfer and
     * create destination directory if needed.
     *
     * @param action Flag to control action to do.
     *
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    private void transfer (RecursiveAction action) throws GLib.Error, GLib.IOError {
        calc_size();
        this.action = action;
        if (is_file || (same_fs && action == RecursiveAction.MOVE)) {
            var f_to_parent = f_to.get_parent();
            if (f_to_parent != null && !f_to_parent.query_exists())
                f_to_parent.make_directory_with_parents();
            transfer_file (f_from, f_to, total_size);
        } else {
            if (!f_to.query_exists())
                f_to.make_directory_with_parents();
            do_recursively (f_from, f_to);
            if (this.action == RecursiveAction.MOVE)
                f_from.delete();
        }
    }

    /**
     * Wrapper to call recursive copy method (and avoid file names here).
     *
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    public void copy() throws GLib.Error, GLib.IOError {
        transfer (RecursiveAction.COPY);
        debug_msg (_("Copying finished.\n"));
    }

    /**
     * Wrapper to call recursive move method (and avoid file names here).
     *
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    public void move() throws GLib.Error, GLib.IOError {
        transfer (RecursiveAction.MOVE);
        debug_msg (_("Moving finished.\n"));
    }

    /**
     * Do all the recursive work and take care of all different flag types.
     *
     * @param from {@link GLib.File} to do action from.
     * @param dest {@link GLib.File} to do action to.
     * @throws GLib.Error Throw on file query errors.
     * @throws GLib.IOError Throw on failed I/O operations.
     */
    private void do_recursively (File from, File dest) throws Error, IOError {
        FileEnumerator enumerator = from.enumerate_children ("standard::*",
                                                             query_flag,
                                                             cancellable);
        FileInfo info = null;
        double size = 0;
        while (cancellable.is_cancelled() == false &&
               ((info = enumerator.next_file (cancellable)) != null)) {

            if (counter_on)
                size = (double) info.get_size();

            if (action == RecursiveAction.COUNT)
                total_size += size;

            /* Current processed file object is a directory. */
            if (info.get_file_type() == FileType.DIRECTORY) {
                var new_from = from.resolve_relative_path (info.get_name());
                var new_dest = dest.resolve_relative_path (info.get_name());

                /* Create directory if it does not exist already. */
                if (action == RecursiveAction.COUNT)
                    size_to_trans += size;
                else if (!new_dest.query_exists())
                    new_dest.make_directory (cancellable);
                /* Only count if needed. */
                //TODO: Is this faster when we just count or when we check
                //      the flags?
                if (counter_on) {
                    current_size += size;
                    byte_count_changed (current_size / total_size);
                }

                do_recursively (new_from, new_dest);

                /* Clean directory on move. */
                if (action == RecursiveAction.MOVE)
                    new_from.delete (cancellable);

            /* Current processed file object is a file. */
            } else {
                if (action == RecursiveAction.COUNT)
                    ++count_total;

                var new_from = from.resolve_relative_path (info.get_name());
                var new_dest = dest.resolve_relative_path (info.get_name());

                transfer_file (new_from, new_dest, size);
            }
        }

        if (cancellable.is_cancelled())
            throw new IOError.CANCELLED (_("File copying cancelled."));
    }

    /**
     * Do the file transfer of a single file.
     *
     * @param from {@link GLib.File} to do action from.
     * @param dest {@link GLib.File} to do action to.
     * @param size Total size of files.
     * @throws GLib.Error Throw on file query errors.
     */
    private void transfer_file (File from, File dest, double size = 0) throws GLib.Error {
        /*
        * Cancel here if file should not be overwritten (either skip
        * or let user decide manually).
        */
        if (dest.query_exists() && action != RecursiveAction.COUNT) {
            /* SKIP_EXISTENT */
            if (rec_flag == CopyRecursiveFlags.SKIP_EXISTENT ||
                    rec_flag == (CopyRecursiveFlags.SKIP_EXISTENT | CopyRecursiveFlags.NO_COUNT)) {
                if (action != RecursiveAction.COUNT)
                    debug_msg (_("Skip %s\n"), dest.get_path());
                if (counter_on) {
                    current_size += size;
                    byte_count_changed (current_size / total_size);
                    ++count_current;
                    num_count_changed (count_current, count_total);
                }
                return;
            /* WARN_OVERWRITE */
            } else if ((rec_flag == CopyRecursiveFlags.WARN_OVERWRITE ||
                    rec_flag == (CopyRecursiveFlags.WARN_OVERWRITE | CopyRecursiveFlags.NO_COUNT)) &&
                    !warn_overwrite (from.get_path(), dest.get_path())) {
                debug_msg (_("Skip overwrite from '%s' to '%s'.\n"), from.get_path(),
                                                                     dest.get_path());
                if (counter_on) {
                    current_size += size;
                    byte_count_changed (current_size / total_size);
                    ++count_current;
                    num_count_changed (count_current, count_total);
                }
                return;
            }
        } else if (action == RecursiveAction.COUNT)
            size_to_trans += size;

        /* Do the actual file transfer action. */
        switch (action) {
            case RecursiveAction.COPY:
                debug_msg (_("Copy from '%s' to '%s'.\n"), from.get_path(),
                                                           dest.get_path());
                if (counter_on) {
                    from.copy (dest, copy_flag, cancellable, (cur, tot) => {
                        byte_count_changed ((current_size + (double) cur)/ total_size);
                    });
                    current_size += size;
                    ++count_current;
                    num_count_changed (count_current, count_total);
                } else
                    from.copy (dest, copy_flag, cancellable);
                break;
            //TODO: Exactly same as copying. Do this the more elegant way.
            case RecursiveAction.MOVE:
                debug_msg (_("Move from '%s' to '%s'.\n"), from.get_path(),
                                                           dest.get_path());
                if (counter_on) {
                    from.move (dest, copy_flag, cancellable, (cur, tot) => {
                        byte_count_changed ((current_size + (double) cur)/ total_size);
                    });
                    current_size += size;
                    ++count_current;
                    num_count_changed (count_current, count_total);
                } else
                    from.move (dest, copy_flag, cancellable);
                break;
            case RecursiveAction.COUNT:
                break;
            default:
                bug_msg (_("Unexpected enum value: %s: %u\n"), "common - RecursiveAction", action);
                break;
        }
    }
}


/**
 * Remove file or directory / directory content recursively.
 *
 * @param path File or directory to remove.
 * @param recursively If `false` don't remove directories. Only useful if
                      {@link path} is directory. To also remove parent, enable
                      {@link with_parent}.
 * @param with_parent Remove current directory. Maybe only useful if
                      {@link recursively} is enabled.
 *
 * @return `true` on success else `false`.
 */
public bool remove_recursively (string path,
                                bool recursively = true,
                                bool with_parent = false) throws GLib.IOError {
    var f = File.new_for_path (path);
    if (!f.query_exists())
        throw new IOError.NOT_FOUND (_("file does not exist: %s"), path);

    var filetype = f.query_file_type (FileQueryInfoFlags.NONE, null);
    switch (filetype) {
        case FileType.REGULAR:
            try {
                return f.delete();
            } catch (GLib.Error e) {
                throw new IOError.FAILED (_("cannot delete file '%s': %s"), f.get_path(), e.message);
            }
        case FileType.DIRECTORY:
            FileEnumerator enumerator;
            try {
                enumerator = f.enumerate_children ("standard::*",
                                                   FileQueryInfoFlags.NONE,
                                                   null);
            } catch (GLib.Error e) {
                throw new IOError.FAILED (_("cannot get children of '%s': %s"), f.get_path(), e.message);
            }

            FileInfo? info = null;
            try {
                while ((info = enumerator.next_file()) != null) {
                    var new_file = f.resolve_relative_path (info.get_name());
                    if (info.get_file_type() == FileType.DIRECTORY) {
                        if (recursively) {
                            remove_recursively_int (new_file);
                            try {
                                new_file.delete();
                            } catch (GLib.Error e) {
                                throw new IOError.FAILED (_("cannot delete file '%s': %s"), new_file.get_path(), e.message);
                            }
                        }
                    } else
                        try {
                            new_file.delete();
                        } catch (GLib.Error e) {
                            throw new IOError.FAILED (_("cannot delete file '%s': %s"), new_file.get_path(), e.message);
                        }
                }
            } catch (GLib.IOError e) {
                throw e;
            } catch (GLib.Error e) {
                throw new IOError.FAILED (_("cannot enumerate children of '%s': %s"), path, e.message);
            }

            if (with_parent)
                try {
                    return f.delete();
                } catch (GLib.Error e) {
                    throw new IOError.FAILED (_("cannot delete file '%s': %s"), path, e.message);
                }
            else
                return true;
        default:
            throw new IOError.NOT_SUPPORTED (_("no regular file or directory: %s"), path);
    }
}


private void remove_recursively_int (File f) throws GLib.IOError {
    FileEnumerator enumerator;
    try {
        enumerator = f.enumerate_children ("standard::*",
                                           FileQueryInfoFlags.NONE,
                                           null);
    } catch (GLib.Error e) {
        throw new IOError.FAILED (_("cannot get children of '%s': %s"), f.get_path(), e.message);
    }

    FileInfo? info = null;
    try {
        while ((info = enumerator.next_file()) != null) {
            var new_file = f.resolve_relative_path (info.get_name());
            if (info.get_file_type() == FileType.DIRECTORY) {
                remove_recursively_int (new_file);
                try {
                    new_file.delete();
                } catch (GLib.Error e) {
                    throw new IOError.FAILED (_("cannot delete file '%s': %s"), new_file.get_path(), e.message);
                }
            } else
                try {
                    new_file.delete();
                } catch (GLib.Error e) {
                    throw new IOError.FAILED (_("cannot delete file '%s': %s"), new_file.get_path(), e.message);
                }
        }
    } catch (GLib.IOError e) {
        throw e;
    } catch (GLib.Error e) {
        throw new IOError.FAILED (_("cannot enumerate children of '%s': %s"), f.get_path(), e.message);
    }
}


/**
 * Generate list of filename parts spited on {@link GLib.Path.DIR_SEPARATOR}.
 *
 * @param path Pathname to split.
 * @param basename Control return of absolute or relative parts of path.
 * @param root Prepend root path or not.
 * @return If basename is `false`, return list of full paths. Else return
 *         absolute paths.
 */
public static string[] split_path (string path, bool basename = true, bool root = true) {
    string[] pathlist = {};
    string subpath = path;

    /* Strip root from path name. */
    var rootfound = false;
    if (Path.skip_root (path) != null) {
        var rootlesspart = Path.skip_root (path);
        var rootindex = subpath.last_index_of (rootlesspart);
        if (root) {
            pathlist += subpath[0:byte_index_to_character_index (subpath, rootindex)];
            if (!basename)
                rootfound = true;
        }
        subpath = rootlesspart;
    }

    /* Strip path delimiter. */
    var dirsepindex = subpath.last_index_of (Path.DIR_SEPARATOR_S);
    if (dirsepindex != -1) {
        var dirsepindexch = byte_index_to_character_index (subpath, dirsepindex);
        if (subpath.length - dirsepindexch == Path.DIR_SEPARATOR_S.length)
            subpath = subpath[0:dirsepindexch];
    }

    /* Generate list of file parts. */
    string[] tmppathlist = {};
    while (subpath != "" && subpath != ".") {
        if (basename)
            tmppathlist += Path.get_basename (subpath);
        else
            tmppathlist += subpath;
        subpath = Path.get_dirname (subpath);
    }

    /* Reverse order of file parts list and add it to final list. */
    for (int i = tmppathlist.length - 1; i >= 0; --i)
        if (rootfound)
            pathlist += pathlist[0] + tmppathlist[i];
        else
            pathlist += tmppathlist[i];

    return pathlist;
}


public static int byte_index_to_character_index (string text, int byte_index, bool silent = false) {
    if (!text.valid_char (byte_index)) {
        if (!silent)
            error_msg (_("No character found at byte index %d: %s\n"), byte_index, text);
        return -1;
    }

    for (var i = 0; i < text.char_count(); ++i)
        if (text.index_of_nth_char (i) == byte_index)
            return i;

    assert_not_reached();
}


/**
 * Save content to file.
 *
 * @param filename Filename where to save buffer.
 * @param text Content to save.
 * @return On success return `true` else `false`.
 */
public bool save_file (string filename, string text) {
    var file = File.new_for_path (filename);

    /* TODO: First parameter can be used to check if file has changed.
     *       The second parameter can enable/disable backup file. */
    try {
        var fos = file.replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
        var dos = new DataOutputStream (fos);
        dos.put_string (text);
        dos.flush();
        dos.close();
        msg (_("File saved: %s\n"), file.get_path());
        return true;
    } catch (GLib.IOError e) {
        errmsg (_("Could not update file: %s\n"), e.message);
    } catch (GLib.Error e) {
        errmsg (_("Could not open file writable: %s\n"), e.message);
    }
    return false;
}


/**
 * Compare two versions. Delimiter is a dot.
 *
 * @param ver_a First version.
 * @param ver_b Second version.
 * @return If first version is smaller return -1. If second version is smaller
 *         return 1. On equality return 0.
 */
public int comp_version (string ver_a, string ver_b) {
    /* Epoch check. */
    string[] a_ep_parts = ver_a.split (":", 2);
    string[] b_ep_parts = ver_b.split (":", 2);
    var eps = a_ep_parts.length - b_ep_parts.length;
    if (eps > 0)
        return 1;
    else if (eps < 0)
        return -1;
    else if (a_ep_parts.length == 2) {
        var ret = comp_version_part (a_ep_parts[0], b_ep_parts[0]);
        if (ret != 0)
            return ret;
    }

    string[] a_parts = a_ep_parts[a_ep_parts.length - 1].split (".");
    string[] b_parts = b_ep_parts[b_ep_parts.length - 1].split (".");

    var max = (a_parts.length < b_parts.length) ? a_parts.length : b_parts.length;

    for (var i = 0; i < max; ++i) {
        var ret = comp_version_part (a_parts[i], b_parts[i]);
        if (ret != 0)
            return ret;
    }

    var ret = a_parts.length - b_parts.length;
    if (ret > 0)
        return 1;
    else if (ret < 0)
        return -1;
    return 0;
}


/**
 * Direct string comparison (leading zeros removed).
 *
 * @param a First version.
 * @param a Second version.
 * @return If first version is smaller return -1. If second version is smaller
 *         return 1. On equality return 0.
 */
internal inline int comp_version_part (string a, string b) {
    /* Ignore leading zeros. */
    uint a_start = 0;
    while (a_start < a.length && a[a_start] == '0')
        ++a_start;
    uint b_start = 0;
    while (b_start < b.length && b[b_start] == '0')
        ++b_start;
    var ret = a[a_start:a.length].length - b[b_start:b.length].length;
    if (ret > 0)
        return 1;
    else if (ret < 0)
        return -1;

    ret = strcmp (a[a_start:a.length], b[b_start:b.length]);
    if (ret > 0)
        return 1;
    else if (ret < 0)
        return -1;
    return 0;
}


/* Message methods. */
/**
 * Print debug message only if debulevel is high enough.
 *
 * @param format Printf string.
 * @param ... Printf variables.
 */
public inline void debug_msg (string format, ...) {
    debug_msg_level (1, format.vprintf (va_list()));
}

public inline void debug_msg_level (int level, string format, ...) {
    if (Args.debuglevel >= level)
        stdout.printf (format.vprintf (va_list()));
}

public inline void warning_msg (string format, ...) {
    stdout.printf (_("Warning: ") + format.vprintf (va_list()));
}

public inline void error_msg (string format, ...) {
    stderr.printf (_("Error: ") + format.vprintf (va_list()));
}

public inline void bug_msg (string format, ...) {
    // TRANSLATORS: Very important string ;) . Thanks btw. for your translation!
    stderr.printf (format.vprintf (va_list()) + _("Please report a bug!\n"));
}

public inline void msg (string format, ...) {
    stdout.printf (format.vprintf (va_list()));
}

public inline void errmsg (string format, ...) {
    stderr.printf (format.vprintf (va_list()));
}


public class Pair<K,V> : Gee.Map.Entry<K,V> {
    private K _key;
    private V _value;
    public override K key { get { return _key; } }
    public override V value {
        get { return _value; }
        set { _value = value; }
    }
    public override bool read_only { get { return false; } }

    public Pair (K key, V value) {
        _key = key;
        _value = value;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
