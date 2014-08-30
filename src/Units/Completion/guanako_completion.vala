/*
 * src/completion_provider.vala
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
using Guanako;
using Vala;
namespace Guanako {
public class GuanakoCompletion : Gtk.SourceCompletionProvider, Object {
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;
    public Gtk.SourceBuffer srcbuffer = null;
    public Gtk.SourceView srcview = null;
    public Project guanako_project = null;
    public Vala.SourceFile source_file = null;

    construct {
        Gdk.Pixbuf icon = this.get_icon();

        this.proposals = new GLib.List<Gtk.SourceCompletionItem>();
    }

    public string get_name() {
        return this.name;
    }

    public int get_priority() {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }

    Project.CompletionRun completion_run = null;
    bool completion_run_queued = false;
    //SuperSourceView.LineAnnotation current_symbol_annotation = null;
    TextMark completion_mark; /* The mark at which the proposals were generated */
    string completion_stmt;
    int completion_col;
    int completion_line;
    SourceCompletionContext completion_context;
    public void populate (SourceCompletionContext context) {

        /* Get current line */
        completion_mark = srcbuffer.get_insert();
        TextIter iter;
        srcbuffer.get_iter_at_mark (out iter, completion_mark);

        TextIter match_sem;
        iter.backward_search (";", TextSearchFlags.TEXT_ONLY, null, out match_sem, null);
        if (!iter.backward_search (";", TextSearchFlags.TEXT_ONLY, null, out match_sem, null))
            srcbuffer.get_iter_at_offset(out match_sem, 0);

        TextIter match_brk;
        if (iter.backward_search ("}", TextSearchFlags.TEXT_ONLY, null, out match_brk, null))
            if (match_brk.compare (match_sem) > 0)
                match_sem = match_brk;
        if (iter.backward_search ("{", TextSearchFlags.TEXT_ONLY, null, out match_brk, null))
            if (match_brk.compare (match_sem) > 0)
                match_sem = match_brk;

        lock (completion_run) {
            completion_line = iter.get_line() + 1;
            completion_col = iter.get_line_offset();
            completion_stmt = srcbuffer.get_text (match_sem, iter, false).replace("\n", "");
            completion_context = context;

            completion_run_queued = true;
            if (completion_run != null) {
                completion_run.abort_run();
                return;
            }
            if (completion_stmt.strip() == "") { // && !srcbuffer.last_key_valid) {
                if (completion_context is SourceCompletionContext)
                    completion_context.add_proposals (this, new GLib.List<Gtk.SourceCompletionItem>(), true);

                return;
            }
            completion_run = new Project.CompletionRun (guanako_project);
        }

        try {
            new Thread<void*>.try ("Completion", () => {
                /* Get completion proposals from Guanako */
                while (true) {
                    completion_run = new Project.CompletionRun (guanako_project);

                    completion_run_queued = false;
                    var guanako_proposals = completion_run.run (source_file,
                                        completion_line, completion_col, completion_stmt);

                    lock (completion_run) {
                        if (completion_run_queued)
                            continue;
                        if (guanako_proposals == null) {
                            if (!completion_run_queued) {
                                completion_run = null;
                                break;
                            } else
                                continue;
                        }
                    }
                    Symbol current_symbol = null;
                    if (completion_run.cur_stack.size > 0)
                        current_symbol = completion_run.cur_stack.last();

                    /*GLib.Idle.add (() => {
                        project.completion_finished (current_symbol);
                        return false;
                    });*/

                    /* Assign icons and pass the proposals on to Gtk.SourceView */
                    var props = new GLib.List<Gtk.SourceCompletionItem>();
                    foreach (Gee.TreeSet<CompletionProposal> list in guanako_proposals)
                        foreach (CompletionProposal guanako_proposal in list) {
                            if (guanako_proposal.symbol.name != null) {

                                Gdk.Pixbuf pixbuf = null;//get_pixbuf_for_symbol (guanako_proposal.symbol);

                                var item = new ComplItem (guanako_proposal.symbol.name,
                                                        guanako_proposal.symbol.name,
                                                        pixbuf,
                                                        null,
                                                        guanako_proposal);
                                props.append (item);
                            }
                        }
                    GLib.Idle.add (() => {
                        if (!completion_run_queued && completion_context is SourceCompletionContext)
                            completion_context.add_proposals (this, props, true);
                        return false;
                    });
                    lock (completion_run) {
                        if (!completion_run_queued) {
                            completion_run = null;
                            break;
                        }
                    }
                }
                return null;
            });
        } catch (GLib.Error e) {
            errmsg ("Could not launch completion thread successfully: %s\n", e.message);
        }
    }

    public unowned Gdk.Pixbuf? get_icon() {
        if (this.icon == null) {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default();
            try {
                this.icon = theme.load_icon ("dialog-information", 16, 0);
            } catch (GLib.Error e) {
                errmsg ("Could not load theme icon: %s\n", e.message);
            }
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {
        var prop = ((ComplItem)proposal).guanako_proposal;

        /* Count backward from completion_mark instead of iter (avoids wrong insertion if the user is typing fast) */
        TextIter start;
        srcbuffer.get_iter_at_mark (out start, completion_mark);
        start.backward_chars (prop.replace_length);

        srcbuffer.delete (ref start, ref iter);
        srcbuffer.insert (ref start, prop.symbol.name, prop.symbol.name.length);

        /* After activating a proposal, immediately queue a new completion request (to keep the completion window open) */
        GLib.Idle.add (()=>{
            srcview.show_completion();
            return false;
        });
        return true;
    }

    public Gtk.SourceCompletionActivation get_activation() {
        return Gtk.SourceCompletionActivation.INTERACTIVE |
               Gtk.SourceCompletionActivation.USER_REQUESTED;
    }

    Box box_info_frame = new Box (Orientation.VERTICAL, 0);
    Widget info_inner_widget = null;
    public unowned Gtk.Widget? get_info_widget (Gtk.SourceCompletionProposal proposal) {
        return box_info_frame;
    }

    public int get_interactive_delay() {
        return -1;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context,
                                Gtk.SourceCompletionProposal proposal,
                                Gtk.TextIter iter) {
        var mark = srcbuffer.get_insert();
        TextIter cursor_iter;
        srcbuffer.get_iter_at_mark (out cursor_iter, mark);

        var prop = ((ComplItem)proposal).guanako_proposal;
        cursor_iter.backward_chars (prop.replace_length);
        iter = cursor_iter;
        return true;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal,
                             Gtk.SourceCompletionInfo info) {
        if (info_inner_widget != null) {
            info_inner_widget.destroy();
            info_inner_widget = null;
        }

        var prop = ((ComplItem)proposal).guanako_proposal;
        if (prop is Method) {
            var mth = prop.symbol as Method;
            var vbox = new Box (Orientation.VERTICAL, 0);
            string param_string = "";
            foreach (Vala.Parameter param in mth.get_parameters())
                param_string += param.variable_type.data_type.name + " " + param.name + ", ";
            if (param_string.length > 1)
                param_string = param_string.substring (0, param_string.length - 2);
            else
                // TRANSLATORS: Context: Parameters: none
                param_string = "none";
            vbox.pack_start (new Label ("Parameters:\n" + param_string + "\n\n"
                             // TRANSLATORS:
                             // Returns a return value (programming).
                                        + "Returns:\n" +
                                        mth.return_type.data_type.name));
            info_inner_widget = vbox;
        } else
            info_inner_widget = new Label (prop.symbol.name);

        info_inner_widget.show_all();
        box_info_frame.pack_start (info_inner_widget, true, true);
    }
}

/**
 * {@link Gtk.SourceCompletionItem} enhanced to carry a reference to the
 * corresponding Guanako proposal.
 */
class ComplItem : SourceCompletionItem {
    public ComplItem (string label, string text, Gdk.Pixbuf? icon, string? info, CompletionProposal guanako_proposal) {
        Object (label: label, text: text, icon: icon, info: info);
        this.guanako_proposal = guanako_proposal;
    }
    public CompletionProposal guanako_proposal;
}
}
// vim: set ai ts=4 sts=4 et sw=4
