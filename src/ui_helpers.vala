/*
 * src/ui_helpers.vala
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

using Gtk;
using GLib;

/**
 * Custom {@link Gtk.Entry} class.
 *
 * Check proper user input. Project names have to consist of "normal"
 * characters only (see regex below). Otherwise cmake would break.
 *
 * Provide two signals valid_input and invalid_input to signal if text is empty
 * or not.
 *
 */
/*
 * TODO: Perhaps we should internally handle special characters with
 *       underscore.
 */
public class Entry : Gtk.Entry {
    /**
     * Id of timer.
     */
    private uint timer_id = 0;
    /**
     * Label to show error message.
     */
    private Label err_label;
    /**
     * Regex of valid characters.
     */
    private Regex valid_chars;
    /**
     * Delay in seconds.
     */
    private uint delay_sec;
    /**
     * Label can be resetted when valid input is provided.
     */
    private bool label_resettable;

    /**
     * Create Entry and connect signals to input.
     */
    public Entry.with_inputcheck (Label err_label,
                                  Regex valid_chars,
                                  uint delay_sec = 5) {
        this.err_label = err_label;
        this.valid_chars = valid_chars;
        this.delay_sec = delay_sec;
        this.label_resettable = false;

        insert_text.connect ((new_text) => {
            this.ui_check_input (new_text);
        });
        changed.connect (() => {
            if (this.text != "")
                valid_input();
            else
                invalid_input();
        });
    }

    /**
     * Destroy object and disable timer.
     */
    ~Entry() {
        this.disable_timer();
    }

    /**
     * Check text for valid input and (re)set {@link err_label} with timer
     * accordingly.
     *
     * @param input_text Text to check.
     */
    public void ui_check_input (string input_text) {
        MatchInfo match_info = null;  // init to null to make valac happy
        if (!this.valid_chars.match (input_text, 0, out match_info)) {
            this.err_label.set_label (_("Invalid character: '") + match_info.get_string() +
                                    _("' Please choose one from: ") + this.valid_chars.get_pattern());
            this.label_resettable = false;
            this.disable_timer();  // reset timer to let it start again
            this.timer_id = Timeout.add_seconds (this.delay_sec, (() => {
                this.err_label.set_label ("");
                return true;
            }));
            Signal.stop_emission_by_name (this, _("insert_text"));
        } else if (this.label_resettable) {
            this.label_resettable = false;
            this.err_label.set_label ("");
        }
    }

    /**
     * Emit when input was valid.
     */
    public signal void valid_input();
    /**
     * Emit when input was invalid.
     */
    public signal void invalid_input();

    /**
     * If resettable is true. Label will be resettet with next user input.
     *
     * @param error_msg Error message to show in {@link err_label}.
     * @param delay Delay in seconds to show error in {@link err_label}.
     * @param resettable {@link err_label} will be resetted with valid input.
     */
    public void set_label_timer (string error_msg, uint delay, bool resettable = true) {
        this.err_label.set_label (error_msg);
        this.label_resettable = resettable;
        this.disable_timer();
        this.timer_id = Timeout.add_seconds (delay, (() => {
            this.err_label.set_label ("");
            return true;
        }));
    }

    /**
     * Disable timer.
     */
    public void disable_timer() {
        if (this.timer_id != 0)
            Source.remove (this.timer_id);
    }
}


/**
 * Simple warning dialog. Check {@link Gtk.ResponseType.YES} or
 * {@link Gtk.ResponseType.NO}.
 *
 * @param warn_msg Text of warning.
 * @return Return {@link Gtk.ResponseType}.
 */
public int ui_ask_warning (string warn_msg) {
    var dlg = new MessageDialog (window_main,
                                 DialogFlags.MODAL,
                                 MessageType.WARNING,
                                 ButtonsType.YES_NO,
                                 warn_msg,
                                 null);
    int ret = dlg.run();
    dlg.destroy();
    return ret;
}


/**
 * Types of "root" trees in project browser (source files, build files,
 * packages).
 */
public enum StoreType {
    PACKAGE,
    PACKAGE_TREE,
    FILE,
    DIRECTORY,
    FILE_TREE
}


/**
 * Build {@link Gtk.TreeStore} with files. Each directory has its own leaves.
 *
 * @param storename Name of store.
 * @param files List of files to add to store.
 * @param store {@link Gtk.TreeStore} to initialize.
 * @param pathmap Map from filepaths to {@link Gtk.TreeIter} to build up tree
 *                correctly.
 */
public void build_file_treestore (string storename,
                                  string[] files,
                                  ref TreeStore store,
                                  ref Gee.HashMap<string, TreeIter?> pathmap) {
        TreeIter iter_base;
        store.append (out iter_base, null);
        store.set (iter_base, 0, storename, 1, StoreType.FILE_TREE, -1);

        var pfile = File.new_for_path (project.project_path);
        foreach (string file in files) {
            var name = pfile.get_relative_path (File.new_for_path (file));
            var pathparts = split_path (name, false);

            if (pathparts.length == 0) {
                bug_msg (_("Couldn't add element to TreeStore '%s': %s\n"), storename, file);
                return;
            }
            for (int depth = 0; depth < pathparts.length; ++depth) {
                if (pathparts[depth] in pathmap)
                    continue;

                TreeIter iter;
                if (depth == 0)
                    store.append (out iter, iter_base);
                else
                    store.append (out iter, pathmap[Path.get_dirname (pathparts[depth])]);

                StoreType store_type;
                if (depth < pathparts.length - 1)
                    store_type = StoreType.DIRECTORY;
                else
                    store_type = StoreType.FILE;
                store.set (iter, 0, Path.get_basename (pathparts[depth]), 1, store_type, -1);

                pathmap[pathparts[depth]] = iter;
            }
        }
}


/**
 * Build plain {@link Gtk.TreeStore}.
 *
 * To build up TreeStore with leaves, look at {@link build_file_treestore}.
 *
 * @param storename Name of store.
 * @param elements List of elements to add to store.
 * @param store {@link Gtk.TreeStore} to initialize.
 */
public void build_plain_treestore (string storename, string[] elements, ref TreeStore store) {
    TreeIter iter_base;
    store.append (out iter_base, null);
    store.set (iter_base, 0, storename, 1, StoreType.PACKAGE_TREE, -1);

    foreach (string element in elements) {
        TreeIter iter;
        store.append (out iter, iter_base);
        store.set (iter, 0, element, 1, StoreType.PACKAGE, -1);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
