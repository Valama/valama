/*
 * src/ui/structure_view.vala
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

using Gtk;
using Clutter;
using GtkClutter;
using Vala;

public class UiStructureView : UiElement {

    public UiStructureView() {
        var box_main = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        var toolbar_title = new Toolbar ();
        toolbar_title.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var ti_title = new ToolItem();
        ti_title.add (new Label (_("Search")));
        toolbar_title.add(ti_title);

        var separator_stretch = new SeparatorToolItem();
        separator_stretch.set_expand (true);
        separator_stretch.draw = false;
        toolbar_title.add (separator_stretch);

        var btn_update_all = new ToolButton (null, "update symbols");
        btn_update_all.is_important = true;
        btn_update_all.clicked.connect (() => {
            update_stuff();
        });
        toolbar_title.add (btn_update_all);

        var btn_update_lines = new ToolButton (null, "update refs");
        btn_update_lines.is_important = true;
        btn_update_lines.clicked.connect (update_lines);
        toolbar_title.add (btn_update_lines);

        box_main.pack_start (toolbar_title, false, true);

        embed = new GtkClutter.Embed();
        stage = embed.get_stage();

        var scrw = new ScrolledWindow(null, null);
        scrw.add (embed);

        box_main.pack_start (scrw);

        stage.background_color = Clutter.Color () { red = 100, green = 100, blue = 100, alpha = 255 };

        widget = box_main;
        if (false == true)
            update_stuff();
    }
    GtkClutter.Embed embed;
    Clutter.Actor stage;

    public override void build() {}

    void update_stuff() {
        float countx = 0;
        float county = 0;
        foreach (Vala.SourceFile file in project.guanako_project.sourcefiles) {
            var vs_file = new vsFile(file);
            vs_files[file] = vs_file;

            vs_file.box.x = countx;
            vs_file.box.y = county;

            stage.add_child (vs_file.box);
            countx += 300;
            if (countx == 1500) {
                countx = 0;
                county += 500;
            }
        }
        embed.set_size_request (1500, (int)county + 500);
        /*var visitor = new Guanako.SymbolVisitor((smb, depth)=>{

            last_text = vs_file.add_symbol (smb, depth, countx);
            stage.add (last_text);
            return Guanako.IterCallbackReturns.CONTINUE;
        });*/
        Guanako.iter_symbol (project.guanako_project.root_symbol, (smb, depth)=>{
            if (depth > 0) {
                var file = smb.source_reference.file;
                if (file in vs_files.keys) {
                    stdout.printf (smb.name + "\n");
                    stdout.printf (@"File $(file.filename) in list\n");
                    vs_files[file].add_symbol (smb, depth);
                }

            }
            return Guanako.IterCallbackReturns.CONTINUE;
        });
        GLib.Timeout.add (1000, () => {
        foreach (vsFile vs_file in vs_files.values)
            foreach (Symbol smb in vs_file.map_symbols.keys) {
                if (!(smb is Subroutine || smb is Variable))
                    continue;
                var refs = Guanako.Refactoring.find_references (project.guanako_project, smb.source_reference.file, smb);
                foreach (SourceReference re in refs) {
                    var smb_at_pos = project.guanako_project.get_symbol_at_pos (re.file, re.begin.line, re.begin.column);
                    if (smb_at_pos != null) {
                        var ctext_dec = vs_file.map_symbols[smb];
                        var ctext_ref = vs_files[re.file].map_symbols[smb_at_pos];
                        vs_file.references.add(reference() {from_text = ctext_dec, to_text = ctext_ref, to_symbol = smb_at_pos, to_file = vs_files[re.file]});
                    }
                }
            }
            return false;
        });
    }

    void update_lines() {
        foreach (vsFile vs_file in vs_files.values)
            vs_file.update_ref_lines (stage);
    }

    internal struct reference {
        //Symbol from_symbol;
        Symbol to_symbol;
        Clutter.Text from_text;
        Clutter.Text to_text;
        vsFile to_file;
    }


    internal static Clutter.Color color_of_symbol (Symbol smb) {
        if (smb is Subroutine)
            return Clutter.Color.from_string ("yellow");
        else if (smb is Variable)
            return Clutter.Color.from_string ("blue");
        else if (smb is Namespace)
            return Clutter.Color.from_string ("red");
        else if (smb is Class)
            return Clutter.Color.from_string ("green");
        else
            return Clutter.Color.from_string ("white");
    }

    internal Gee.HashMap <Vala.SourceFile, vsFile> vs_files = new Gee.HashMap <Vala.SourceFile, vsFile>();
    internal class vsFile : Object {
        public vsFile (Vala.SourceFile file) {

            var splt = file.filename.split ("/");
            var text = new Clutter.Text.full ("Bitstream Vera Sans 12",
                              splt[splt.length-1],
                              Clutter.Color.from_string ("white"));

            box.reactive = true;
            box.enter_event.connect(()=>{
                foreach (Clutter.Actor rect in ref_lines)
                    rect.opacity = 255;
                return false;
            });
            box.leave_event.connect(()=>{
                foreach (Clutter.Actor rect in ref_lines)
                    rect.opacity = 25;
                return false;
            });

            box.add_action (new Clutter.DragAction());
            box.set_layout_manager (new Clutter.FixedLayout());
            vbox_private.set_layout_manager (new Clutter.FlowLayout(Clutter.FlowOrientation.VERTICAL));
            vbox_public.set_layout_manager (new Clutter.FlowLayout(Clutter.FlowOrientation.VERTICAL));
            vbox_private.x = 150;
            vbox_private.y = 30;
            vbox_public.y = 30;
            box.add_child (text);
            box.add_child (vbox_private);
            box.add_child (vbox_public);
        }
        public void update_ref_lines (Clutter.Actor stage) {
            foreach (Clutter.Actor r in ref_lines)
                r.destroy();
            foreach (reference refe in references) {
                var box1 = refe.from_text.get_allocation_box();
                var box2 = refe.to_text.get_allocation_box();
                var r = draw_line (box1.x1 + box.x, box1.y1 + box.y, box2.x1 + refe.to_file.box.x, box2.y1 + refe.to_file.box.y, color_of_symbol (refe.to_symbol));
                ref_lines.add (r);
                stage.add (r);
            }
        }
        float county = 30;
        public Clutter.Text add_symbol (Symbol smb, int depth) {
            var text = new Clutter.Text.full ("Bitstream Vera Sans 8",
                              smb.name, color_of_symbol(smb));

            text.x = depth * 20;

            if (smb.access == SymbolAccessibility.PUBLIC)
                vbox_public.add_child (text);
            else
                vbox_private.add_child (text);

            county += text.height;
            map_symbols[smb] = text;
            return text;
        }

        public Clutter.Actor box = new Clutter.Actor();
        public Clutter.Actor vbox_public = new Clutter.Actor();
        public Clutter.Actor vbox_private = new Clutter.Actor();
        public Gee.LinkedList<Clutter.Actor> ref_lines = new Gee.LinkedList<Clutter.Actor>();
        public Gee.LinkedList<reference?> references = new Gee.LinkedList<reference?>();
        public Gee.HashMap <Symbol, Clutter.Text> map_symbols = new Gee.HashMap <Symbol, Clutter.Text> ();

        Clutter.Actor draw_line (float x1, float y1, float x2, float y2, Clutter.Color color) {
            #if VALA_0_28
			    var r = new Clutter.Actor();
			#else
			    var r = new Clutter.Rectangle();
			#endif
            var dist = Math.sqrtf ((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2));

            r.width = 2;
            r.height = dist;
            r.x = x1;
            r.y = y1;
            if (y2 > y1)
                r.rotation_angle_z = -Math.asinf ((x2 - x1) / dist) / Math.PI * 180;
            else
                r.rotation_angle_z = Math.asinf ((x2 - x1) / dist) / Math.PI * 180 + 180;
            r.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            r.set_easing_duration (250);
            r.opacity = 25;
            #if VALA_0_28
                r.background_color = color;
            #else
			    r.color = color;
			#endif
            return r;
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
