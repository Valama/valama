/*
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

/**
 * Flags to control FileTransfer class.
 */
public enum CopyRecursiveFlags {
    /**
     * Don't count and don't skip or warn on existing files.
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
     * Skip if file already exists.
     */
    NO_COUNT_SKIP_EXISTENT, //FIXME: Is it possible to pass multiple enum vars to method arguments?
    /**
     * Warn if file already exists.
     */
    NO_COUNT_WARN_OVERWRITE
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
            throw new IOError.NOT_FOUND ("No such file.");

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
             * If destination object already exists and is a diretory, make
             * f_to to a child of it.
             */
            if (f_to.query_exists()) {
                if (info_to.get_file_type() == FileType.DIRECTORY)
                    f_to = f_to.resolve_relative_path (f_from.get_basename());
            }
        }
    }

    /**
     * Percentage of file transfer.
     */
    public signal void byte_count_changed (double percent_done);

    /**
     * Number of current transferred files (and total amount).
     *
     * Emit on change.
     */
    public signal void num_count_changed (int cur, int tot);

    /*
     * Signal with both file names to indicate if file should be overwritten.
     * Return true to overwrite file. To skip return false.
     *
     * Emit on change.
     */
    public signal bool warn_overwrite (string from_name, string to_name);

    /**
     * Calculate total size of transfers.
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
        if (!same_fs && fs_free <= size_to_trans) {
            throw new GLib.IOError.NO_SPACE ("Not enough space available.");
        }
    }

    /**
     * Call the transfer methods properly, calulcate before transfer and create
     * destination directory if needed.
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
     */
    public void copy() throws GLib.Error, GLib.IOError {
        transfer (RecursiveAction.COPY);
#if DEBUG
        stdout.printf ("Copying finished.\n");
#endif
    }

    /**
     * Wrapper to call recursive move method (and avoid file names here).
     */
    public void move() throws GLib.Error, GLib.IOError {
        transfer (RecursiveAction.MOVE);
#if DEBUG
        stdout.printf ("Moving finished.\n");
#endif
    }

    /**
     * Do all the recursive work and take care of all different flag types.
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
                if (!new_dest.query_exists() && action != RecursiveAction.COUNT) {
                    new_dest.make_directory (cancellable);
                    /* Only count if needed. */
                    //TODO: Is this faster when we just count or when we check
                    //      the flags?
                    if (counter_on) {
                        current_size += size;
                        byte_count_changed (current_size / total_size);
                    }
                } else if (action == RecursiveAction.COUNT)
                    size_to_trans += size;

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
            throw new IOError.CANCELLED ("File copying cancelled.");
    }

    /**
     * Do the file transfer of a single file.
     */
    private void transfer_file (File from, File dest, double size = 0) throws GLib.Error {
        /*
        * Cancel here if file should not be overwritten (either skip
        * or let user decide manually).
        */
        if (dest.query_exists() && action != RecursiveAction.COUNT) {
            /* SKIP_EXISTENT */
            if (rec_flag == CopyRecursiveFlags.SKIP_EXISTENT ||
                    rec_flag == CopyRecursiveFlags.NO_COUNT_SKIP_EXISTENT) {
#if DEBUG
                if (action != RecursiveAction.COUNT)
                    stdout.printf ("Skip %s\n", dest.get_path());
#endif
                if (counter_on) {
                    current_size += size;
                    byte_count_changed (current_size / total_size);
                    ++count_current;
                    num_count_changed (count_current, count_total);
                }
                return;
            /* WARN_OVERWRITE */
            } else if ((rec_flag == CopyRecursiveFlags.WARN_OVERWRITE ||
                    rec_flag == CopyRecursiveFlags.NO_COUNT_WARN_OVERWRITE) &&
                    !warn_overwrite (from.get_path(), dest.get_path())) {
#if DEBUG
                stdout.printf ("Skip overwrite from '%s' to '%s'.\n", from.get_path(),
                                                                      dest.get_path());
#endif
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
#if DEBUG
                stdout.printf ("Copy from '%s' to '%s'.\n", from.get_path(),
                                                            dest.get_path());
#endif
                if (counter_on) {
                    from.copy (dest, copy_flag, cancellable, (cur, tot) => {
                        byte_count_changed((current_size + (double) cur)/ total_size);
                    });
                    current_size += size;
                    ++count_current;
                    num_count_changed (count_current, count_total);
                } else
                    from.copy (dest, copy_flag, cancellable);
                break;
            //TODO: Exactly same as copying. Do this the more elegant way.
            case RecursiveAction.MOVE:
#if DEBUG
                stdout.printf ("Move from '%s' to '%s'.\n", from.get_path(),
                                                            dest.get_path());
#endif
                if (counter_on) {
                    from.move (dest, copy_flag, cancellable, (cur, tot) => {
                        byte_count_changed((current_size + (double) cur)/ total_size);
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
                stderr.printf ("Unknown action to perform (please report a bug): %d\n", action);
                break;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
