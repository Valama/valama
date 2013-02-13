/*
 * src/ui_create_project_dialog.vala
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
using Gtk;

/**
 * Template selection widget; Can return selected item
 */
public class uiTemplateSelector {
    public uiTemplateSelector() {

        tree_view = new TreeView();
        var listmodel = new ListStore (2, typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (listmodel);

        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 1);
        tree_view.insert_column_with_attributes (-1,
                                                 _("Templates"),
                                                 new CellRendererText(),
                                                 "markup",
                                                 0);

        available_templates = load_templates ("en");

        foreach (ProjectTemplate template in available_templates) {
            TreeIter iter;
            listmodel.append (out iter);
            listmodel.set (iter, 0, "<b>" + template.name + "</b>\n" + template.description, 1, template.icon);
        }

        this.widget = tree_view;
    }

    TreeView tree_view;
    ProjectTemplate[] available_templates;
    public Widget widget;

    public ProjectTemplate? get_selected_template() {
        TreeModel model;
        var paths = tree_view.get_selection().get_selected_rows (out model);
        foreach (TreePath path in paths) {
            var indices = path.get_indices();
            return available_templates[indices[0]];
        }
        return null;
    }
}


/**
 * Project creation dialog.
 *
 * @return Return a {@link ValamaProject} of the created template-based project.
 */
public ValamaProject? ui_create_project_dialog() {
    var dlg = new Dialog.with_buttons (_("Choose project template"),
                                       window_main,
                                       DialogFlags.MODAL,
                                       Stock.CANCEL,
                                       ResponseType.CANCEL,
                                       Stock.OPEN,
                                       ResponseType.ACCEPT,
                                       null);

    dlg.set_size_request (420, 300);
    dlg.resizable = false;

    var selector = new uiTemplateSelector();

    var box_main = new Box (Orientation.VERTICAL, 0);
    box_main.pack_start (selector.widget, true, true);


    var lbl = new Label(_("Project name"));
    lbl.halign = Align.START;
    box_main.pack_start(lbl, false, false);

    var ent_proj_name_err = new Label ("");
    ent_proj_name_err.sensitive = false;

    Regex valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
    var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars);
    ent_proj_name.set_placeholder_text (_("Project name"));
    box_main.pack_start (ent_proj_name, false, false);
    box_main.pack_start (ent_proj_name_err, false, false);

    ent_proj_name.valid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.ACCEPT, true);
    });
    ent_proj_name.invalid_input.connect (() => {
        dlg.set_response_sensitive (ResponseType.ACCEPT, false);
    });


    lbl = new Label (_("Location"));
    lbl.halign = Align.START;
    box_main.pack_start (lbl, false, false);

    var chooser_target = new FileChooserButton (_("New project location"), Gtk.FileChooserAction.SELECT_FOLDER);
    box_main.pack_start (chooser_target, false, false);

    box_main.show_all();
    dlg.get_content_area().pack_start (box_main);
    dlg.set_response_sensitive (ResponseType.ACCEPT, false);

    var res = dlg.run();

    var template = selector.get_selected_template();
    string proj_name = ent_proj_name.text;
    string target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                            chooser_target.get_current_folder(),
                                            proj_name);

    dlg.destroy();
    if (res == ResponseType.CANCEL || res == ResponseType.DELETE_EVENT || template == null)
        return null;

    try { //TODO: Separate different error catchings to provide differentiate error messages.
        //TODO: Add progress bar and at least warn on overwrite (don't skip
        //      without warning).
        new FileTransfer (template.path,
                          target_folder,
                          CopyRecursiveFlags.SKIP_EXISTENT).copy();
        new FileTransfer (Path.build_path (Path.DIR_SEPARATOR_S,
                                           target_folder,
                                           "template.vlp"),
                          Path.build_path (Path.DIR_SEPARATOR_S,
                                           target_folder,
                                           proj_name + ".vlp"),
                          CopyRecursiveFlags.SKIP_EXISTENT).move();

        //TODO: Do this with cmake buildsystem plugin.
        string buildsystem_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                   Config.PACKAGE_DATA_DIR,
                                                   "buildsystems",
                                                   "cmake",
                                                   "buildsystem");
        new FileTransfer (buildsystem_path,
                          target_folder,
                          CopyRecursiveFlags.SKIP_EXISTENT).copy();
        project.save();
    } catch (GLib.Error e) {
        errmsg (_("Could not copy templates for new project: %s\n"), e.message);
    }


    ValamaProject new_proj = null;
    try {
        new_proj = new ValamaProject (Path.build_path (Path.DIR_SEPARATOR_S,
                                                       target_folder,
                                                       proj_name + ".vlp"));
        new_proj.project_name = proj_name;
    } catch (LoadingError e) {
        errmsg (_("Couln't load new project: %s\n"), e.message);
    }
    return new_proj;
}

// vim: set ai ts=4 sts=4 et sw=4
