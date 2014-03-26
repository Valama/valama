/*
 * src/ui/super_source_view.vala
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
using Vala;

/**
 * Enhanced GtkSourceView
 */
public class SuperSourceView : SourceView {
    public SuperSourceView(SourceBuffer bfr) {
        this.buffer = bfr;
        int old_line = -1;

        this.motion_notify_event.connect ((event)=>{
            int bfrx, bfry;
            this.window_to_buffer_coords (TextWindowType.WIDGET, (int)event.x, (int)event.y, out bfrx, out bfry);
            TextIter line_iter;
            this.get_line_at_y (out line_iter, bfry, null);
            int line = line_iter.get_line();
            if (line != old_line) {
                old_line = line;
                foreach (Animation anim in animations)
                    anim.mouse_move (line);
            }
            return false;
        });

        Timeout.add (30, ()=>{
            foreach (Animation anim in animations)
                if (anim.animated) {
                    anim.advance ();
                    anim.queue_draw ();
                }
            while (true) {
                for (int q = 0; q < animations.size; q++)
                    if (animations[q].finished) {
                        animations[q].queue_draw ();
                        animations.remove_at(q);
                        continue;
                    }
                break;
            }
            return true;
        });
    }
    public override bool draw (Cairo.Context cr) {
        base.draw (cr);
        foreach (Animation anim in animations)
            anim.draw (cr);
        return true;
    }
    public void highlight_line (int line) {
        var animation = new LineHighlight();
        animation.line = line;
        animation.view = this;
        animations.add (animation);
    }
    public LineAnnotation annotate (int line, string text, double r, double g, double b, bool always_visible, int offset = 1) {
        var animation = new LineAnnotation(this, line, r, g, b, offset);
        animation.text = text;
        animation.always_visible = always_visible;
        animations.add (animation);
        return animation;
    }
    internal Gee.ArrayList<Animation> animations = new Gee.ArrayList<Animation>();

    public abstract class Animation {
        public bool finished = false;
        public bool animated = false;
        internal SuperSourceView view;
        internal abstract void advance();
        internal abstract void queue_draw();
        internal abstract void mouse_move (int line);
        internal abstract void draw (Cairo.Context cr);
    }
    public class LineAnnotation : Animation{
        public LineAnnotation(SuperSourceView view, int line, double r, double g, double b, int offset) {
            this.r = r;
            this.g = g;
            this.b = b;
            this.view = view;
            this.line = line;
            this.offset = offset;
            animated = false;
            queue_draw();
        }
        public int line;
        public int offset;
        public string text;
        public bool always_visible = false;

        public double r = 1.0;
        public double g = 0.0;
        public double b = 0.0;

        bool visible = false;
        double proc = 0.0;
        public override void mouse_move (int line) {
            if (visible != (this.line == line)) {
                animated = true;
                visible = this.line == line;
            }
        }
        public override void queue_draw() {
            int y, height, wx, wy;
            TextIter iter;
            view.buffer.get_iter_at_line (out iter, line);
            view.get_line_yrange (iter, out y, out height);
            view.buffer_to_window_coords (TextWindowType.WIDGET, 0, y, out wx, out wy);
            view.queue_draw_area (0, wy + offset * height - 3, view.get_allocated_width(), height + 6);
        }
        public override void advance() {
            if (!always_visible) {
                if (visible && proc < 1.0)
                    proc += 0.1;
                else if (!visible && proc > 0.0)
                    proc -= 0.1;
                else
                    animated = false;
            }
        }
        public override void draw(Cairo.Context cr) {
            if (always_visible)
                proc = 1.0;
            else
                if (proc == 0)
                    return;
            int y, height, wx, wy;
            TextIter iter;

            view.buffer.get_iter_at_line (out iter, line);
            view.get_line_yrange (iter, out y, out height);
            view.buffer_to_window_coords (TextWindowType.WIDGET, 0, y, out wx, out wy);
            var gutter_width = 
            #if GTK_SOURCE_VIEW_3_12
				this.view.get_window (TextWindowType.LEFT).get_width();
			#else
				this.view.get_gutter (TextWindowType.LEFT).get_window().get_width();
			#endif

            cr.select_font_face ("Monospace", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size (10);
            Cairo.TextExtents extents;
            cr.text_extents (text, out extents);

            rounded_rectanlge (cr, gutter_width, wy + offset * height, extents.width + 6, extents.height + 3, 7);
            cr.set_source_rgba (r, g, b, 1.0 * proc);
            cr.set_line_width (2);
            cr.stroke_preserve();
            cr.set_source_rgba (r + 0.3, g + 0.3, b + 0.3, 0.75 * proc);
            cr.fill();

            cr.move_to (gutter_width + 3, wy + (offset + 1) * height - 5);
            cr.set_source_rgba (0.0, 0.0, 0.0, 1.0 * proc);
            cr.show_text (text);
        }
        void rounded_rectanlge (Cairo.Context cr, double x, double y, double width, double height, double r) {
            cr.move_to (x, y);
            cr.line_to (x + width - r, y);
            cr.curve_to(x + width, y, x + width, y, x + width, y + r);
            cr.line_to(x + width, y + height - r);
            cr.curve_to(x + width, y + height, x + width, y + height, x + width - r, y + height);
            cr.line_to(x + r, y + height);
            cr.curve_to(x, y + height, x, y + height, x, y + height - r);
            cr.line_to(x, y + r);
            cr.curve_to(x, y, x, y, x + r, y);
        }
    }
    class LineHighlight : Animation{
        public LineHighlight() {
            animated = true;
        }
        public int line;
        double proc = 0;
        public override void mouse_move (int line) {
        }
        public override void queue_draw() {
            int y, height, wx, wy;
            TextIter iter;
            view.buffer.get_iter_at_line (out iter, line);
            view.get_line_yrange (iter, out y, out height);
            view.buffer_to_window_coords (TextWindowType.WIDGET, 0, y, out wx, out wy);
            view.queue_draw_area (0, wy - 10, view.get_allocated_width(), height + 20);
        }
        public override void advance() {
            proc += 0.3;
            finished = proc >= 10;
        }
        public override void draw(Cairo.Context cr) {
            int y, height, wx, wy;
            TextIter iter;

            view.buffer.get_iter_at_line (out iter, line);
            view.get_line_yrange (iter, out y, out height);
            view.buffer_to_window_coords (TextWindowType.WIDGET, 0, y, out wx, out wy);

            int width = view.get_allocated_width();// - view.get_margin_left() - 10;
            cr.move_to (wx, wy - proc);
            cr.set_source_rgba (1.0, 0, 0, 1.0 - proc / 10);
            cr.rel_line_to (width, 0);
            cr.rel_line_to (0, height + proc * 2);
            cr.rel_line_to (-width, 0);
            cr.close_path ();
            cr.stroke();
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
