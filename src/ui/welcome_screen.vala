/*
 * src/welcome_screen.vala
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
using Gtk;
using Gdk;


/**
 * Helper class to add a new page to {@link WelcomeScreen} creation steps.
 */
public abstract class TemplatePage : Object {
    /**
     * {@link Gtk.Widget} with the page to be displayed.
     */
    public Widget widget { get; protected set; }

    /**
     * Share template over all instances.
     */
    public static ProjectTemplate? template = null;

    /**
     * Emit signal to initialize object (e.g. add accelerators).
     *
     * @return Page description.
     */
    public signal string? selected();

    /**
     * Emit signal when no longer focused (e.g. to disable accelerators).
     *
     * @param status `true` to commit changes (usually with next-button press).
     */
    public signal void deselected (bool status);

    /**
     * Emit to change previous-button sensitivity.
     */
    public signal void prev (bool status);
    /**
     * Emit to change next-button sensitivity.
     */
    public signal void next (bool status);
}


/**
 * Show start screen with last opened projects and allow creation of new
 * project from templates.
 */
public class WelcomeScreen : Alignment {
    /**
     * Fixed width of all {@link Gtk.Grid}s (@link main_screen} and
     * {@link creator}.
     */
    const int WIDTH = 600;
    /**
     * Fixed height of all {@link Gtk.Grid}s (@link main_screen} and
     * {@link creator}.
     */
    const int HEIGHT = 400;

    /**
     * {@link Gtk.ToolButton} to go back in creation procedure.
     */
    private ToolButton btn_prev;
    /**
     * {@link Gtk.ToolButton} to continue with creation procedure.
     */
    private ToolButton btn_next;

    /**
     * Holds all creation steps.
     */
    private Notebook nbook;
    /**
     * Steps (pages) to go backward with previous-button. If negative, reset
     * to start page.
     */
    private int nbook_prev_n;
    /**
     * Steps (pages) to go forward with next-button. If negative, reset to
     * start page.
     */
    private int nbook_next_n;

    /**
     * Current selected recent project.
     */
    private RecentInfo? current_recent;
    /**
     * Current page of creation step.
     */
    private Widget? current_page;

    /**
     * Start page.
     */
    private Widget main_screen;
    /**
     * Selector/creator main widget. Provides previous- and next-buttons. To
     * switch between creation steps.
     */
    private Widget creator;
    /**
     * File chooser widget.
     */
    private Widget opener;

    /**
     * Initialization state. Signal emissions will be tracked after
     * initialized. Activate with {@link initialize}.
     */
    private bool initialized;
    /**
     * Last clicked creator button. `true` if {@link btn_next} else if
     * {@link btn_prev} `false`.
     */
    private bool is_next;

    /**
     * Emitted when a item in recent project list is selected.
     *
     * @param btn {@link Gtk.Button} associated to selected (!= loaded) project.
     */
    private signal void recent_selected (Button btn);

    /**
     * Emitted when start page is shown (e.g. creation steps are canceled).
     */
    private signal void main_screen_selected();

    /**
     * Change heading text of creation step.
     *
     * @param desc Text.
     */
    private signal void selector_heading (string desc);
    /**
     * Change description text of creation step.
     *
     * @param desc Text.
     */
    private signal void selector_description (string desc);

    /**
     * Emit when new {@link ValamaProject} is loaded.
     *
     * @param project Loaded project.
     */
    public signal void project_loaded (ValamaProject? project);

    /**
     * Emitted when project was opened over recent projects list.
     *
     * @param btn {@link Gtk.Button} which was clicked.
     */
    private signal void recent_btn_selected (Button btn);


    /**
     * Initialize all main elements (start page and creator).
     *
     * Note: Entry point for project open button is first creation step
     *       (notebook page). Entry point of new project button is second
     *       creation step.
     *
     * @param build_default Setup default creation steps.
     */
    public WelcomeScreen (bool build_default = true) {
        this.xalign = 0.5f;
        this.yalign = 0.5f;
        this.xscale = 0.0f;
        this.yscale = 0.0f;

        current_recent = null;
        current_page = null;

        initialized = false;
        is_next = false;

        nbook_prev_n = 1;
        nbook_next_n = 1;

        build_main();
        build_creator();
        build_opener();

        project_loaded.connect ((project) => {
            if (project != null) {
                this.remove (this.get_child());
                this.add (main_screen);
            }
        });

        if (build_default)
            init_default_pages();

        this.add (main_screen);
        this.show_all();
    }

    /**
     * Mark class initialized. Only after initialization all signals are
     * tracked.
     */
    public inline void initialize() {
        initialized = true;
    }

    /**
     * Build up main {@link Gtk.Grid} with recent information.
     */
    private void build_main() {
        var grid_main = new Grid();
        grid_main.column_spacing = 30;
        grid_main.row_spacing = 5;
        grid_main.set_size_request (WIDTH, HEIGHT);

        Image? img_valama = null;
        try {
            img_valama = new Image.from_pixbuf(new Pixbuf.from_file (
                                        Path.build_path (Path.DIR_SEPARATOR_S,
                                                         Config.PACKAGE_DATA_DIR,
                                                         "valama-text.png")));
            grid_main.attach (img_valama, 1, 4, 1, 16);
        } catch (GLib.Error e) {
            errmsg (_("Could not load Valama text logo: %s\n"), e.message);
        }

        /* Recent projects. */
        var scrw = new ScrolledWindow (null, null);
        grid_main.attach (scrw, 0, 2, 1, 19);
        scrw.width_request = 400;
        scrw.vexpand = true;

        Grid grid_recent_projects;
        var move_grid_elements = false;
        recent_build (out grid_recent_projects);
        scrw.add_with_viewport (grid_recent_projects);
        /* Update added project files immediately. */
        recentmgr.changed.connect (() => {
            if (!move_grid_elements) {
                //TODO: Find a better solution. scrw.remove (grid_...) won't work.
                scrw.forall_internal (false, (child) => {
                    scrw.remove (child);
                });
                recent_build (out grid_recent_projects);
                scrw.add_with_viewport (grid_recent_projects);
                grid_recent_projects.show_all();
            }
        });
        recent_btn_selected.connect ((btn) => {
            move_grid_elements = true;
            /* Move selected element to top. */
            grid_recent_projects.remove (btn);
            grid_recent_projects.insert_row (0);
            grid_recent_projects.attach (btn, 0, 0, 1, 1);
            move_grid_elements = false;
        });

        var lbl_recent_projects = new Label ("<b>" + Markup.escape_text (_("Recent projects")) + "</b>");
        lbl_recent_projects.use_markup = true;
        lbl_recent_projects.halign = Align.START;
        lbl_recent_projects.sensitive = false;
        grid_main.attach (lbl_recent_projects, 0, 1, 1, 1);


        /* Buttons. */
        var btn_create = new Button.with_label (_("Create new project"));
        btn_create.width_request = 250;
        btn_create.vexpand = false;
        btn_create.clicked.connect (() => {
            this.remove (main_screen);
            this.add (creator);
            selector_heading (_("Create project"));
            /* Force switch_page signal to emit all selected signals. */
            nbook.switch_page (nbook.get_nth_page (1), 1);  // 0th page is opener
        });
        grid_main.attach (btn_create, 1, 2, 1, 1);

        var btn_open = new Button.with_label (_("Open project"));
        btn_open.vexpand = false;
        btn_open.clicked.connect (() => {
            this.remove (main_screen);
            this.add (creator);
            selector_heading (_("Open project"));
            nbook.switch_page (nbook.get_nth_page (0), 0);
        });
        recent_selected.connect (() => {
            btn_open.sensitive = (current_recent != null) ? true : false;
        });
        grid_main.attach (btn_open, 1, 3, 1, 1);

        var btn_quit = new Button.with_label (_("Quit"));
        btn_quit.clicked.connect (Gtk.main_quit);
        grid_main.attach (btn_quit, 1, 20, 1, 1);


        main_screen = grid_main;
    }

    /**
     * Newer elements ({@link Gtk.RecentInfo.get_modified} come ealier.
     *
     * @param a First info.
     * @param b Second info.
     * @return 0 if equal, 1 if a < b, else -1.
     */
    private int cmp_recent_info (RecentInfo a, RecentInfo b) {
        if (a.get_modified() == b.get_modified())
            return 0;
        return (a.get_modified() < b.get_modified()) ? 1 : -1;
    }

    /**
     * Build recent loaded project list.
     *
     * @param grid_recent_projects {@link Gtk.Grid} to fill with projects (as
     *                             {@link Gtk.Button} objects.
     */
    private void recent_build (out Grid grid_recent_projects) {
        grid_recent_projects = new Grid();
        if (recentmgr.get_items().length() > 0) {
            /* Sort elements before. */
            var recent_items = new Gee.TreeSet<RecentInfo> (cmp_recent_info);
            foreach (var info in recentmgr.get_items())
                recent_items.add (info);
            int cnt = 0;
            foreach (var info in recent_items) {
                var btn_proj = new Button();
                grid_recent_projects.attach (btn_proj, 0, cnt++, 1, 1);
                btn_proj.hexpand = true;
                /* Select first entry as default. */
                if (current_recent == null) {
                    current_recent = info;
                    btn_proj.relief = ReliefStyle.HALF;
                } else
                    btn_proj.relief = ReliefStyle.NONE;
                btn_proj.event.connect ((event) => {
                    switch (event.type) {
                        case EventType.@2BUTTON_PRESS:
                            btn_proj.activate();
                            try {
                                project_loaded (new ValamaProject (info.get_uri(), Args.syntaxfile));
                                /* Move element to top. */
                                recent_btn_selected (btn_proj);
                            } catch (LoadingError e) {
                                error_msg (_("Could not load new project: %s\n"), e.message);
                            }
                            return false;
                        case EventType.BUTTON_PRESS:
                            current_recent = info;
                            recent_selected (btn_proj);
                            btn_proj.relief = ReliefStyle.HALF;
                            return false;
                        default:
                            return false;
                    }
                });
                recent_selected.connect ((btn) => {
                    if (btn != btn_proj)
                        btn_proj.relief = ReliefStyle.NONE;
                });

                var grid_label = new Grid();
                btn_proj.add (grid_label);

                var lbl_proj_name = new Label ("<b>" + Markup.escape_text (info.get_display_name()) + "</b>");
                grid_label.attach (lbl_proj_name, 0, 0, 1, 1);
                lbl_proj_name.ellipsize = Pango.EllipsizeMode.END;
                lbl_proj_name.halign = Align.START;
                lbl_proj_name.use_markup = true;

                var lbl_proj_path = new Label ("<i>" + Markup.escape_text (info.get_uri_display()) + "</i>");
                grid_label.attach (lbl_proj_path, 0, 1, 1, 1);
                lbl_proj_path.sensitive = false;
                lbl_proj_path.ellipsize = Pango.EllipsizeMode.START;
                lbl_proj_path.halign = Align.START;
                lbl_proj_path.use_markup = true;
            }
        } else {
            var lbl_no_recent_projects = new Label (_("No recent projects"));
            grid_recent_projects.attach (lbl_no_recent_projects, 0, 0, 1, 1);
            lbl_no_recent_projects.sensitive = false;
            lbl_no_recent_projects.expand = true;
        }
    }

    /**
     * Build up creator {@link Gtk.Grid} with previous- and next-button.
     *
     * Creation steps must be added with {@link add_page} or {@link add_tpage}.
     */
    private void build_creator() {
        var grid_creator = new Grid();
        grid_creator.set_size_request (WIDTH, HEIGHT);

        var toolbar = new Toolbar();
        toolbar.width_request = WIDTH;
        grid_creator.attach (toolbar, 0, 0, 1, 1);

        btn_prev = new ToolButton (new Image.from_icon_name ("go-previous-symbolic",
                                                             IconSize.BUTTON),
                                                             _("Back"));
        toolbar.add (btn_prev);
        btn_prev.clicked.connect (() => {
            is_next = false;
            if (nbook_prev_n >= 0) {
                if (nbook_prev_n > nbook.page || nbook.page <= 0) {  // "<=" for empty notebook
                    this.remove (creator);
                    this.add (main_screen);
                    main_screen_selected();
                    /*
                     * TODO: Proper solution to work around half pressed button
                     *       after swichting back again.
                     */
                    btn_prev.forall ((child) => {
                        var btn = child as Button;
                        if (btn != null) {
                            btn.sensitive = false;
                            btn.sensitive = true;
                            //btn.button_release_event...
                        }
                    });
                } else
                    nbook.page -= nbook_prev_n;
            }
        });
        main_screen_selected.connect (() => {
            /* Reset to default values. */
            current_page = null;
            TemplatePage.template = null;
        });

        var creator_lbl_item = new ToolItem();
        toolbar.add (creator_lbl_item);
        var heading = "";
        var creator_lbl = new Label ("<b>" + Markup.escape_text (heading) + "</b>\n");
        creator_lbl_item.add (creator_lbl);
        creator_lbl.use_markup = true;
        creator_lbl.justify = Justification.CENTER;
        creator_lbl_item.set_expand (true);
        selector_heading.connect ((desc) => {
            heading = desc;
            creator_lbl.label = "<b>" + Markup.escape_text (desc) + "</b>";
        });
        selector_description.connect ((desc) => {
            creator_lbl.label = "<b>" + Markup.escape_text (heading)
                                + "</b>\n" + Markup.escape_text (desc);
        });

        btn_next = new ToolButton (new Image.from_icon_name ("go-next-symbolic",
                                                             IconSize.BUTTON),
                                                             _("Next"));
        toolbar.add (btn_next);
        btn_next.clicked.connect (() => {
            is_next = true;
            if (nbook_next_n >= 0)
                nbook.page += nbook_next_n;
        });

        nbook = new Notebook();
        grid_creator.attach (nbook, 0, 1, 1, 1);
        nbook.show_tabs = false;
        nbook.switch_page.connect_after ((page) => {
            if (initialized)
                current_page = page;
        });

        grid_creator.show_all();
        creator = grid_creator;
    }

    /**
     * Add new creation step.
     *
     * All signals have to be connected manually.
     *
     * @param page Add {@link Gtk.Widget} to creation steps.
     * @param pos Insert step at position. If `null` append it.
     * @deprecated Use {@link add_tpage} instead.
     */
    [Deprecated (replacement = "add_tpage()")]
    private inline void add_page (Widget page, int? pos = null) {
        if (pos == null)
            nbook.append_page (page);
        else
            nbook.insert_page (page, null, pos);
    }

    /**
     * Add new creation step and setup common signals.
     *
     * @param page Add {@link TemplatePage.widget} to creation steps.
     * @param pos Insert step at position. If `null` append it.
     */
    public void add_tpage (TemplatePage tpage, int? pos = null,
                                            int prev = 1, int next = 1) {
        add_page (tpage.widget, pos);

        nbook.switch_page.connect ((page, num) => {
            if (initialized) {
                if (tpage.widget == page) {
                    btn_prev.sensitive = true;
                    btn_next.sensitive = true;
                    nbook_prev_n = prev;
                    nbook_next_n = next;
                    var s = tpage.selected();
                    if (s != null)
                        selector_description (s);
                } else if (current_page != null && tpage.widget == current_page)
                    tpage.deselected (is_next);
            }
        });
        tpage.prev.connect ((status) => {
            if (tpage.widget == current_page)
                btn_prev.sensitive = status;
        });
        tpage.next.connect ((status) => {
            if (tpage.widget == current_page)
                btn_next.sensitive = status;
        });
        main_screen_selected.connect (() => {
            tpage.deselected (false);
        });
    }

    /**
     * Initialize default creation steps.
     *
     * Currently:   - project file open element
     *              - template selector
     *              - project settings element
     */
    private void init_default_pages() {
        add_page (opener);
        add_tpage (new UiTemplateSelector(), null, 2);
        add_page (get_simple_setting());

        initialize();
        nbook.show_all();
    }

    /**
     * Build file open element.
     *
     * @param prev Go n steps back with previous-button. If negative reset.
     * @param next Go n steps forward with next-button. If negative reset.
     */
    private void build_opener (int prev = 1, int next = -1) {
        var chooser_open = new FileChooserWidget (FileChooserAction.OPEN);
        chooser_open.expand = true;

        var filter_vlp = new FileFilter();
        filter_vlp.set_filter_name (_("Valama project files (*.vlp)"));
        filter_vlp.add_pattern ("*.vlp");
        chooser_open.add_filter (filter_vlp);
        chooser_open.set_filter (filter_vlp);  // set default filter

        var filter_all = new FileFilter();
        filter_all.set_filter_name (_("All files (*)"));
        filter_all.add_pattern ("*");
        chooser_open.add_filter (filter_all);

        var selected = false;
        chooser_open.selection_changed.connect (() => {
            if (selected && chooser_open == current_page) {
                var selected_filename = chooser_open.get_filename();
                if (selected_filename == null ||  //TODO: Other filetypes?
                            File.new_for_path (selected_filename).query_file_type (
                                                    FileQueryInfoFlags.NONE) != FileType.REGULAR)
                    btn_next.sensitive = false;
                else
                    btn_next.sensitive = selected_filename.has_suffix (".vlp");
            }
        });
        /* Double click. */
        chooser_open.file_activated.connect (() => {
            if (selected && chooser_open == current_page && btn_next.sensitive)
                btn_next.clicked();
        });

        nbook.switch_page.connect ((page) => {
            if (initialized) {
                if (chooser_open == page) {
                    selected = true;
                    btn_prev.sensitive = true;
                    btn_next.sensitive = false;
                    nbook_prev_n = prev;
                    nbook_next_n = next;
                    selector_description (_("Select Valama project file"));
                } else if (current_page != null && chooser_open == current_page)
                    selected = false;
            }
        });
        btn_next.clicked.connect (() => {
            if (selected && chooser_open == current_page)
                try {
                    project_loaded (new ValamaProject (chooser_open.get_filename(), Args.syntaxfile));
                } catch (LoadingError e) {
                    //TODO: Show error message in UI.
                    error_msg (_("Could not load project: %s\n"), e.message);
                }
        });

        opener = chooser_open;
    }

    /**
     * Build project settings element.
     *
     * @param prev Go n steps back with previous-button. If negative reset.
     * @param next Go n steps forward with next-button. If negative reset.
     */
    public Widget get_simple_setting (int prev = 1, int next = -1) {
        var grid_pinfo = new Grid();
        grid_pinfo.column_spacing = 10;
        grid_pinfo.row_spacing = 15;
        grid_pinfo.row_homogeneous = false;
        grid_pinfo.column_homogeneous = true;

        var lbl_pname = new Label (_("Project name"));
        grid_pinfo.attach (lbl_pname, 0, 2, 1, 1);
        lbl_pname.halign = Align.END;

        var valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
        var ent_pname = new Entry.with_inputcheck (null, valid_chars);
        grid_pinfo.attach (ent_pname, 1, 2, 1, 1);
        ent_pname.set_placeholder_text (_("Project name"));

        var selected = false;
        ent_pname.valid_input.connect (() => {
            if (selected && grid_pinfo == current_page)
                btn_next.sensitive = true;
        });
        ent_pname.invalid_input.connect (() => {
            if (selected && grid_pinfo == current_page)
                btn_next.sensitive = false;
        });

        var lbl_plocation = new Label (_("Location"));
        grid_pinfo.attach (lbl_plocation, 0, 5, 1, 1);
        lbl_plocation.halign = Align.END;

        //TODO: Use in place dialog (FileChooserWidget).
        var chooser_location = new FileChooserButton (_("New project location"),
                                                      Gtk.FileChooserAction.SELECT_FOLDER);
        grid_pinfo.attach (chooser_location, 1, 5, 1, 1);

        nbook.switch_page.connect ((page) => {
            if (initialized) {
                if (grid_pinfo == page) {
                    btn_prev.sensitive = true;
                    btn_next.sensitive = false;
                    selected = true;
                    nbook_prev_n = prev;
                    nbook_next_n = next;
                } else if (current_page != null && grid_pinfo == current_page)
                    selected = false;
            }
        });
        btn_next.clicked.connect (() => {
            //FIXME: Find solution where btn_next.sensitive is not important.
            if (selected && btn_next.sensitive && grid_pinfo == current_page &&
                                                TemplatePage.template != null) {
                var target_folder = Path.build_path (Path.DIR_SEPARATOR_S,
                                                     chooser_location.get_current_folder(),
                                                     ent_pname.text);
                var new_project = create_project_from_template (
                                                TemplatePage.template,
                                                target_folder,
                                                ent_pname.text);
                project_loaded (new_project);
            }
        });

        return grid_pinfo;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
