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

        Timeout.add (30, ()=>{
            foreach (SuperSourceViewAnimation anim in animations)
                anim.advance ();
            while (true) {
                for (int q = 0; q < animations.size; q++)
                    if (animations[q].finished) {
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
        foreach (SuperSourceViewAnimation anim in animations)
            anim.draw (cr);
        return true;
    }
    public void highlight_line (int line) {
        var animation = new SuperSourceViewAnimation();
        animation.line = line;
        animation.view = this;
        animations.add (animation);
    }
    Gee.ArrayList<SuperSourceViewAnimation> animations = new Gee.ArrayList<SuperSourceViewAnimation>();

    class SuperSourceViewAnimation {
        internal int line;
        double proc = 0;
        internal TextView view;
        internal bool finished = false;
        internal void advance() {
            proc += 0.3;
            finished = proc >= 10;

            int y, height, wx, wy;
            TextIter iter;
            view.buffer.get_iter_at_line (out iter, line);
            view.get_line_yrange (iter, out y, out height);
            view.buffer_to_window_coords (TextWindowType.WIDGET, 0, y, out wx, out wy);
            view.queue_draw_area (0, wy - 10, view.get_allocated_width(), height + 20);
        }
        internal void draw(Cairo.Context cr) {
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
