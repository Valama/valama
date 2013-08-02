/*
 * src/common/ui_helpers.vala
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
    private Label? err_label;
    /**
     * Regex of valid characters.
     */
    private Regex valid_chars;
    /**
     * Delay in seconds.
     */
    private uint delay_sec;
    /**
     * Label can be reseted when valid input is provided.
     */
    private bool label_resettable;
    /**
     * Reset label to this string.
     */
    private string reset_string;

    /**
     * Create Entry and connect signals to input.
     *
     * @param err_label {@link Gtk.Label} to show error message.
     * @param valid_chars {@link GLib.Regex} with valid characters.
     * @param delay_sec Time to show error message.
     * @param reset_string Reset {@link Gtk.Label} to this string.
     */
    public Entry.with_inputcheck (Label? err_label,
                                  Regex valid_chars,
                                  uint delay_sec = 5,
                                  string reset_string = "") {
        this.err_label = err_label;
        this.valid_chars = valid_chars;
        this.delay_sec = delay_sec;
        this.label_resettable = false;
        this.reset_string = reset_string;

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
            if (err_label != null) {
                this.err_label.set_label (
                    _("Invalid character: '%s' Please choose one from: %s").printf (
                    match_info.get_string(), this.valid_chars.get_pattern()));
                this.label_resettable = false;
            }
            this.disable_timer();  // reset timer to let it start again
            this.timer_id = Timeout.add_seconds (this.delay_sec, (() => {
                if (err_label != null)
                    this.err_label.set_label (reset_string);
                return true;
            }));
            Signal.stop_emission_by_name (this, "insert_text");
        } else if (err_label != null && this.label_resettable) {
            this.label_resettable = false;
            this.err_label.set_label (reset_string);
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
     * If resettable is true. Label will be reseted with next user input.
     *
     * @param error_msg Error message to show in {@link err_label}.
     * @param delay Delay in seconds to show error in {@link err_label}.
     * @param resettable {@link err_label} will be reseted with valid input.
     */
    public void set_label_timer (string error_msg, uint delay, bool resettable = true) {
        this.err_label.set_label (error_msg);
        this.label_resettable = resettable;
        this.disable_timer();
        this.timer_id = Timeout.add_seconds (delay, (() => {
            this.err_label.set_label (reset_string);
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
 * Simple warning dialog with 'yes' and 'no' buttons.
 *
 * Remeber to properly escape extra_text if needed.
 *
 * @param warn_msg Text of warning.
 * @param extra_text Additional information with markdown formatting.
 * @return Return {@link Gtk.ResponseType}, either {@link Gtk.ResponseType.YES}
 *         or {@link Gtk.ResponseType.YES}.
 */
public int ui_ask_warning (string warn_msg, string? extra_text = null) {
    var dlg = new MessageDialog (window_main,
                                 DialogFlags.MODAL,
                                 MessageType.WARNING,
                                 ButtonsType.YES_NO,
                                 warn_msg,
                                 null);
    if (extra_text != null) {
        dlg.secondary_use_markup = true;
        dlg.secondary_text = extra_text;
    }

    int ret = dlg.run();
    dlg.destroy();
    return ret;
}


/**
 * Simple warning dialog with 'discard' 'save' and 'cancel' buttons.
 *
 * Remeber to properly escape extra_text if needed.
 *
 * @param warn_msg Text of warning.
 * @param extra_text Additional information with markdown formatting.
 * @return Return {@link Gtk.ResponseType}.
 */
public int ui_ask_file (string warn_msg, string? extra_text = null) {
    var dlg = new MessageDialog (window_main,
                                 DialogFlags.MODAL,
                                 MessageType.WARNING,
                                 ButtonsType.NONE,
                                 warn_msg,
                                 null);

    if (extra_text != null) {
        dlg.secondary_use_markup = true;
        dlg.secondary_text = extra_text;
    }

    dlg.add_button (_("_Discard"), ResponseType.REJECT);
    dlg.add_button (_("_Save"), ResponseType.ACCEPT);
    dlg.add_button (_("_Cancel"), ResponseType.CANCEL);

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
 * Input will be sorted.
 *
 * @param storename Name of store.
 * @param files List of files to add to store.
 * @param store {@link Gtk.TreeStore} to initialize.
 * @param pathmap Map from file paths to {@link Gtk.TreeIter} to build up tree
 *                correctly.
 */
public void build_file_treestore (string storename,
                                  string[] dirs,
                                  string[] files,
                                  ref TreeStore store,
                                  ref Gee.HashMap<string, TreeIter?> pathmap) {
        TreeIter iter_base;
        store.append (out iter_base, null);
        store.set (iter_base, 0, storename, 1, StoreType.FILE_TREE, -1);

        /* Filename -> filetype mappings. Value is `true` for directories. */
        var tmap = new Gee.TreeMap<string, bool>();
        foreach (var file in files)
            tmap[file] = false;
        foreach (var dir in dirs)
            tmap[dir] = true;

        foreach (var entry in tmap.entries) {
            var pathparts = split_path (project.get_relative_path (entry.key), false);

            /* Project root directory. */
            if (pathparts.length == 0)
                continue;

            for (int depth = 0; depth < pathparts.length; ++depth) {
                if (pathmap.has_key (pathparts[depth]))
                    continue;

                TreeIter iter;
                if (depth == 0)
                    store.append (out iter, iter_base);
                else
                    store.append (out iter, pathmap[Path.get_dirname (pathparts[depth])]);

                StoreType store_type;
                if (entry.value || depth < pathparts.length - 1)
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

/**
 * Load {@link Gdl.DockLayout} from filename.
 *
 * @param layout Layout to load.
 * @param filename Name of file to load layout from.
 * @param section Name of default section to load settings from.
 * @param error Display error if layout file does not exist.
 * @return Return `true` on success else `false`.
 */
public bool load_layout (Gdl.DockLayout layout,
                         string filename,
                         string? section = null,
                         bool error = true) {
    if (!FileUtils.test (filename, FileTest.IS_REGULAR)) {  //TODO: Allow symlinks.
        if (error)
            warning_msg (_("Layout file does not exist: %s\n"), filename);
        else
            debug_msg (_("Layout file does not exist: %s\n"), filename);
        return false;
    }
    debug_msg (_("Load layout...\n"));
    string lsection = (section != null) ? section : "__default__";
    bool ret = layout.load_from_file (filename);
    if (ret)
        debug_msg (_("Layouts loaded from file: %s\n"), filename);
    else
        errmsg (_("Couldn't load layout file: %s\n"), filename);
    return (ret && layout_reload (layout, lsection));
}

/**
 * Reload {@link Gdl.DockLayout}. May be helpful on window resize.
 *
 * @param layout Layout to reload.
 * @param section Name of default section to load settings from.
 * @return Return `true` on success else `false`.
 */
public bool layout_reload (Gdl.DockLayout layout, string section = "__default__") {
    bool ret = layout.load_layout (section);
    if (!ret)
        errmsg (_("Couldn't load layout: %s\n"), section);
    else
        debug_msg (_("Layout loaded: %s\n"), section);
    return ret;
}

/**
 * Save current {@link Gdl.DockLayout} to file.
 *
 * @param layout Layout to save.
 * @param filename Name of file to save layout to.
 * @param section Save specific layout section.
 * @return Return `true` on success else `false`.
 */
public bool save_layout (Gdl.DockLayout layout, string filename,
                         string section = "__default__") {
    layout.save_layout (section);
    bool ret = layout.save_to_file (filename);
    if (!ret)
        errmsg (_("Couldn't save layout to file: %s\n"), filename);
    else
        debug_msg (_("Layout '%s' saved to file: %s\n"), section, filename);
    return ret;
}

// vim: set ai ts=4 sts=4 et sw=4
