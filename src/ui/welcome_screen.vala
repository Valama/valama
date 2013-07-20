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
using Gee;


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
     * List of ids of previous pages. Including of default is not necessary
     */
    public TreeSet<string> possible_prevs = new TreeSet<string>();
    /**
     * List of ids of next pages. Including of default is not necessary.
     */
    public TreeSet<string> possible_nexts = new TreeSet<string>();

    /**
     * Id of page to switch back by default.
     *
     * `prev` or `start` can be used to switch to previous page or start page.
     */
    public string default_prev { get; protected set; default = "prev"; }
    /**
     * Id of page to switch forward by default.
     */
    public string default_next { get; protected set; default = ""; }

    /**
     * Emit signal to initialize object (e.g. add accelerators).
     */
    public signal void selected();
    /**
     * Emit signal when no longer focused (e.g. to disable accelerators).
     *
     * @param status `true` to commit changes (usually with next-button press).
     * @param chpage id of page to switch to or `null` if default page is used.
     */
    public signal void deselected (bool status, string? chpage = null);

    /**
     * Emit to change previous-button sensitivity.
     */
    public signal void prev (bool status);
    /**
     * Emit to change next-button sensitivity.
     */
    public signal void next (bool status);

    public bool prev_default_status { get; protected set; default = true; }
    public bool next_default_status { get; protected set; default = false; }

    /**
     * Directly move to a page.
     *
     * @param prevpage Move to this id or if `null` move to {@link default_prev}
     */
    public signal void move_prev (string? prevpage = null);
    /**
     * Directly move to a page.
     *
     * @param nextpage Move to this id or if `null` move to {@link default_next}
     */
    public signal void move_next (string? nextpage = null);

    public signal void load_project (ValamaProject? project);

    /**
     * Unique template page id.
     *
     * `prev`, `start` are reserved ids.
     */
    public abstract string get_id();

    public string? description { get; protected set; default = null; }

    public string? heading { get; protected set; default = null; }

    protected virtual void init() {}
    public virtual void manual_init() {}

    //TODO: Does this work?
    protected static void switch_default_prev (TemplatePage tpage, string newprev) {
        tpage.default_prev = newprev;
    }
    protected static void switch_default_next (TemplatePage tpage, string newnext) {
        tpage.default_next = newnext;
    }
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
     * Hash of all pages (creation steps).
     */
    private TreeMap<string, TemplatePage> tpagehash = new TreeMap<string, TemplatePage>();

    /**
     * Page id to go back with previous-button.
     *
     * `prev` or `start` can be used to switch to previous page or start page.
     */
    private string prev_id = "start";
    /**
     * Page id where to go forward with next-button.
     */
    private string next_id = "";

    /**
     * Current selected recent project.
     */
    private RecentInfo? current_recent;
    /**
     * Current page of creation step.
     */
    private TemplatePage? current_tpage;

    /**
     * Start page.
     */
    private Widget main_screen;
    /**
     * Selector/creator main widget. Provides previous- and next-buttons. To
     * switch between creation steps.
     */
    private Widget creator;
    private Container creatorpage;

    /**
     * Initialization state. Signal emissions will be tracked after
     * initialized. Activate with {@link initialize}.
     */
    private bool initialized;

    /**
     * Stack of ids of previously visited pages.
     */
    private ArrayQueue<string> prevstack = new ArrayQueue<string>();

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
        current_tpage = null;

        initialized = false;

        build_main();
        build_creator();

        project_loaded.connect ((project) => {
            if (project != null) {
                this.remove (this.get_child());
                this.add (main_screen);
                main_screen_selected();
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

        var evb_extra = new EventBox();
        evb_extra.name = "evb_extra";
        grid_main.attach (evb_extra, 1, 5, 1, 15);

        var grid_extra = new Grid();
        evb_extra.add (grid_extra);
        grid_extra.expand = true;

        var prov = new CssProvider();
        var disp = Gdk.Display.get_default();
        var screen = disp.get_default_screen();
        StyleContext.add_provider_for_screen (screen, prov, STYLE_PROVIDER_PRIORITY_APPLICATION);
        try {  //TODO: Use GResource.
            prov.load_from_data ("""
GtkEventBox#evb_extra {
    background-image: url('%s');
    background-repeat: no-repeat;
    background-position: center;
}
GtkGrid#grid_recent_projects > .button:hover {
    background-image: none;
}
""".printf (Path.build_path (Path.DIR_SEPARATOR_S, Config.PACKAGE_DATA_DIR, "valama-text.png")), -1);
        } catch (GLib.Error e) {
            bug_msg (_("Could not load %s CSS definitions.\n"), "WelcomeScreen");
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
            selector_heading (_("Create project"));
            next_id = "UiTemplateSelector";
            btn_next.clicked();
            this.remove (main_screen);
            this.add (creator);
        });
        grid_main.attach (btn_create, 1, 2, 1, 1);

        var btn_open = new Button.with_label (_("Open project"));
        btn_open.vexpand = false;
        btn_open.clicked.connect (() => {
            try {
                project_loaded (new ValamaProject (current_recent.get_uri_display(), Args.syntaxfile));
            } catch (LoadingError e) {
                //TODO: Show error message in UI.
                error_msg (_("Could not load project: %s\n"), e.message);
            }
        });
        recent_selected.connect (() => {
            btn_open.sensitive = (current_recent != null) ? true : false;
        });
        grid_main.attach (btn_open, 1, 3, 1, 1);

        var btn_load = new Button.with_label (_("Load project"));
        btn_load.vexpand = false;
        btn_load.clicked.connect (() => {
            selector_heading (_("Load project"));
            next_id = "UiTemplateOpener";
            btn_next.clicked();
            this.remove (main_screen);
            this.add (creator);
        });
        grid_main.attach (btn_load, 1, 4, 1, 1);

        var btn_quit = new Button.with_label (_("Quit"));
        btn_quit.clicked.connect (()=>{
            quit_valama();
        });
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
        grid_recent_projects.name = "grid_recent_projects";
        if (recentmgr.get_items().length() > 0) {
            /* Sort elements before. */
            var recent_items = new TreeSet<RecentInfo> (cmp_recent_info);
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
                var doubleclick = false;
                btn_proj.event.connect ((event) => {
                    switch (event.type) {
                        case EventType.@2BUTTON_PRESS:
                            doubleclick = true;
                            return false;
                        case EventType.BUTTON_PRESS:
                            doubleclick = false;
                            current_recent = info;
                            recent_selected (btn_proj);
                            btn_proj.relief = ReliefStyle.HALF;
                            return false;
                        case EventType.BUTTON_RELEASE:
                            if (doubleclick)
                                try {
                                    project_loaded (new ValamaProject (info.get_uri(), Args.syntaxfile));
                                    /* Move element to top. */
                                    recent_btn_selected (btn_proj);
                                } catch (LoadingError e) {
                                    error_msg (_("Could not load new project: %s\n"), e.message);
                                }
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
     * Creation steps must be added with {@link add_tpage}.
     */
    private void build_creator() {
        var grid_creator = new Grid();
        grid_creator.set_size_request (WIDTH, HEIGHT);

        var toolbar = new Toolbar();
        toolbar.width_request = WIDTH;
        grid_creator.attach (toolbar, 0, 0, 1, 1);

        btn_prev = new ToolButton (new Image.from_icon_name ("go-previous-symbolic",
                                                             IconSize.BUTTON),
                                   // TRANSLATORS: Of course not the body part ;) .
                                   // Go to the previous window.
                                                             _("Back"));
        toolbar.add (btn_prev);
        btn_prev.clicked.connect (() => {
            if (prev_id == "start")
                switch_to_main();
            else if (tpagehash.has_key (prev_id)) {
                if (current_tpage != null) {
                    creatorpage.remove (current_tpage.widget);
                    current_tpage.deselected (false);
                }
                switch_tpage (prev_id);

                string? id = null;
                while (true) {
                    id = prevstack.poll_tail();
                    if (id == null)
                        break;
                    else if (id == current_tpage.get_id()) {
                        id = prevstack.poll_tail();
                        break;
                    }
                }

                if (current_tpage.default_prev != "prev")
                    prev_id = current_tpage.default_prev;
                else {
                    if (id != null)
                        prev_id = id;
                    else
                        prev_id = "start";
                }
            } else {
                bug_msg (_("No such id for previous step: %s\n"), prev_id);
                if (current_tpage != null) {
                    creatorpage.remove (current_tpage.widget);
                    current_tpage.deselected (false);
                }
                var id = prevstack.poll_tail();
                if (id != null) {
                    current_tpage = tpagehash[id];
                    creatorpage.add (current_tpage.widget);
                    prev_id = current_tpage.default_prev;
                } else
                    // Go to start.
                    switch_to_main();
            }
        });
        main_screen_selected.connect (() => {
            /* Reset to default values. */
            if (current_tpage != null)
                creatorpage.remove (current_tpage.widget);
            current_tpage = null;
            TemplatePage.template = null;
            prev_id = "start";
            prevstack.clear();
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
            if (next_id == "")
                current_tpage.deselected (true);
            else if (tpagehash.has_key (next_id)) {
                if (current_tpage != null) {
                    prevstack.offer_tail (current_tpage.get_id());
                    creatorpage.remove (current_tpage.widget);
                    current_tpage.deselected (true);
                }
                switch_tpage (next_id);

                if (current_tpage.default_prev != "prev")
                    prev_id = current_tpage.default_prev;
                else {
                    var id = prevstack.peek_tail();
                    if (id != null)
                        prev_id = id;
                    else
                        prev_id = "start";
                }
            } else
                bug_msg (_("No such id for next step: %s\n"), next_id);
        });

        creatorpage = new Box (Orientation.VERTICAL, 0);
        grid_creator.attach (creatorpage, 0, 1, 1, 1);

        grid_creator.show_all();
        creator = grid_creator;
    }

    /**
     * Switch to {@link TemplatePage} with given id.
     *
     * Ensure id exists. Does not set {@link prev_id}.
     */
    private void switch_tpage (string id) {
        current_tpage = tpagehash[id];

        btn_prev.sensitive = current_tpage.prev_default_status;
        btn_next.sensitive = current_tpage.next_default_status;
        next_id = current_tpage.default_next;
        if (current_tpage.heading != null)
            selector_heading (current_tpage.heading);
        if (current_tpage.description != null)
            selector_description (current_tpage.description);

        creatorpage.add (current_tpage.widget);
        current_tpage.selected();
    }

    private void switch_to_main() {
        remove (creator);
        add (main_screen);
        main_screen_selected();
        /*
         * TODO: Proper solution to work around half pressed button
         *       after switching back again.
         */
        btn_prev.forall ((child) => {
            var btn = child as Button;
            if (btn != null) {
                btn.sensitive = false;
                btn.sensitive = true;
                //btn.button_release_event...
            }
        });
    }

    /**
     * Add new creation step and setup common signals.
     *
     * @param tpage Add {@link TemplatePage.widget} to creation steps.
     * @param pos Insert step at position. If `null` append it.
     */
    public void add_tpage (TemplatePage tpage) {
        tpagehash[tpage.get_id()] = tpage;

        tpage.load_project.connect ((project) => {
            project_loaded (project);
        });

        tpage.prev.connect ((status) => {
            if (tpage == current_tpage)
                btn_prev.sensitive = status;
        });
        tpage.next.connect ((status) => {
            if (tpage == current_tpage)
                btn_next.sensitive = status;
        });
        tpage.move_prev.connect ((id) => {
            if (tpage == current_tpage) {
                if (id != null)
                    prev_id = id;
                btn_prev.clicked();
            }
        });
        tpage.move_next.connect ((id) => {
            if (tpage == current_tpage) {
                if (id != null)
                    next_id = id;
                btn_next.clicked();
            }
        });
        main_screen_selected.connect (() => {
            tpage.deselected (false);
        });
    }

    /**
     * Initialize default creation steps.
     *
     * Currently:
     *
     *  * project file open element
     *  * template selector
     *  * project settings element
     */
    private void init_default_pages() {
        add_tpage (new UiTemplateOpener());
        add_tpage (new UiTemplateSelector("UiTemplateSettings"));
        add_tpage (new UiTemplateSettings());

        initialize();
        creatorpage.show_all();
    }
}

// vim: set ai ts=4 sts=4 et sw=4
