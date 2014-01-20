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

namespace WelcomeScreen {

    // Templates for building pages. Pages are created and destroyed on the fly

    protected abstract class TemplatePage : Object {
        public Widget? widget = null;

        public abstract void build();
        public abstract void clean_up();
    }
    // Includes header with prev / next buttons
    protected abstract class TemplatePageWithHeader : TemplatePage {

        public signal void go_to_prev_clicked();
        public signal void go_to_next_clicked();

        protected string heading = "";
        protected string description = "";

        protected ToolButton btn_next;
        protected ToolButton btn_prev;

        public override void build () {

            var box = new Gtk.Box (Orientation.VERTICAL, 0);
            var toolbar = new Toolbar();
            btn_prev = new ToolButton (new Image.from_icon_name ("go-previous-symbolic",
                                                                 IconSize.BUTTON),
                                                                 _("Back"));
            btn_prev.clicked.connect(()=>{go_to_prev_clicked();});
            btn_next = new ToolButton (new Image.from_icon_name ("go-next-symbolic",
                                                                 IconSize.BUTTON),
                                                                 _("Next"));
            btn_next.clicked.connect(()=>{go_to_next_clicked();});

            var lbl_heading_item = new ToolItem();
            var lbl_heading = new Label (null);
            lbl_heading.use_markup = true;
            lbl_heading.justify = Justification.CENTER;
            lbl_heading_item.set_expand (true);
            lbl_heading_item.add (lbl_heading);

            toolbar.add (btn_prev);
            toolbar.add (lbl_heading_item);
            toolbar.add (btn_next);
            box.pack_start (toolbar, false, true);

            box.pack_start (build_inner_widget(), true, true);

            // Set text after build_inner_widget call, so it can be specified there
            lbl_heading.label = "<b>" + Markup.escape_text (heading) + "</b>\n" + Markup.escape_text (description);

            box.set_size_request (600, 400);
            widget = box;
        }

        // Build the actual content (below the header)
        protected abstract Gtk.Widget build_inner_widget();

    }

    /*
     * The actual welcome screen widget, handles showing and linking pages pages.
     * It also, creates the ValamaProject to be passed to main
     */

    public class WelcomeScreen : Alignment{
        public WelcomeScreen() {
            // Center me
            this.xalign = 0.5f;
            this.yalign = 0.5f;
            this.xscale = 0.0f;
            this.yscale = 0.0f;

            this.add(box_main);
            this.show_all();
            show_main_screen();
        }
        // Put pages in a separate container to allow different background color
        //Gtk.Box box_main = new Gtk.Box(Orientation.VERTICAL, 0);
        Gtk.EventBox box_main = new Gtk.EventBox();

        // Methods showing the pages and linking them
        ProjectCreationInfo info;
        private void show_main_screen() {
            var msc = new MainScreen();
            msc.create_button_clicked.connect (()=>{
                show_create_project_template();
            });
            msc.recent_project_selected.connect((project_path)=>{
                try {
                project_loaded (new ValamaProject (project_path, Args.syntaxfile));
                } catch {}
            });
            msc.open_button_clicked.connect(()=>{
                show_open_project();
            });
            switch_to_page(msc);
        }
        private void show_create_project_location() {
            var page = new CreateProjectLocation(ref info);
            page.go_to_prev_clicked.connect(()=>{show_create_project_template();});
            page.go_to_next_clicked.connect(()=>{show_create_project_packages();});
            switch_to_page(page);
        }
        private void show_create_project_template() {
            info = new ProjectCreationInfo();
            var page = new CreateProjectTemplate(ref info);
            page.go_to_prev_clicked.connect(show_main_screen);
            page.go_to_next_clicked.connect(()=>{show_create_project_location();});
            switch_to_page(page);
        }
        private void show_create_project_packages() {
	    var page = new CreateProjectPackages(ref info);
	    page.go_to_prev_clicked.connect(()=>{ show_create_project_location(); });
            page.go_to_next_clicked.connect(()=>{ show_create_project_buildsystem(); });
            switch_to_page(page);
	}
        private void show_create_project_buildsystem() {
            var page = new CreateProjectBuildsystem(ref info);
            page.go_to_prev_clicked.connect(()=>{show_create_project_packages();});
            page.go_to_next_clicked.connect(()=>{project_loaded (create_project_from_template (info));});
            switch_to_page(page);
        }
        private void show_open_project() {
            var page = new OpenProject();
            page.go_to_prev_clicked.connect(()=>{show_main_screen();});
            page.go_to_next_clicked.connect(()=>{
                try {
                project_loaded (new ValamaProject (page.project_filename, Args.syntaxfile));
                } catch {}
            });
            switch_to_page(page);
        }

        //project_loaded (create_project_from_template (info));
        // Abstracts replacing pages
        private TemplatePage? current_page = null;
        private void switch_to_page (TemplatePage new_page) {
            if (current_page != null) {
                current_page.clean_up();
                box_main.remove (current_page.widget);
            }
            current_page = new_page;
            current_page.build();
            box_main.add (current_page.widget);
            current_page.widget.show_all();
        }

        public signal void project_loaded (ValamaProject? project);

    }

}
// vim: set ai ts=4 sts=4 et sw=4
