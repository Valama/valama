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
using Vala;
//namespace Guanako {
public class GuanakoCompletion : Gtk.SourceCompletionProvider, Object {
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;
    public Gtk.SourceBuffer srcbuffer = null;
    public Gtk.SourceView srcview = null;
    private Ui.MainWidget main_widget;
    private Project.ProjectMemberValaSource member;

    public GuanakoCompletion (Ui.MainWidget main_widget, Project.ProjectMemberValaSource member) {
        this.main_widget = main_widget;
        this.member = member;
        Gdk.Pixbuf icon = this.get_icon();

        this.proposals = new GLib.List<Gtk.SourceCompletionItem>();
    }

    public string get_name() {
        return "guanako";
    }

    public int get_priority() {
        return this.priority;
    }

    public bool match (Gtk.SourceCompletionContext context) {
        return true;
    }

    Guanako.Project.CompletionRun completion_run = null;
    bool completion_run_queued = false;
    //SuperSourceView.LineAnnotation current_symbol_annotation = null;
    TextMark completion_mark; /* The mark at which the proposals were generated */
    string completion_stmt;
    int completion_col;
    int completion_line;
    SourceCompletionContext completion_context;
    public void populate (SourceCompletionContext context) {

        // Get current line
        completion_mark = srcbuffer.get_insert();
        TextIter iter;
        srcbuffer.get_iter_at_mark (out iter, completion_mark);

        completion_line = iter.get_line() + 1;
        completion_col = iter.get_line_offset();
        //completion_stmt = ""; //srcbuffer.get_text (match_sem, iter, false).replace("\n", "");

        string[] fragments = new string[0];
        string symbol_read = "";

        int bracket_count = 0;

        while (iter.get_char() != 0) {
          iter.backward_char();
          var iter_char = iter.get_char();

          if (iter_char == ')' || iter_char == '}') {
            fragments += symbol_read;
            symbol_read = "";
            bracket_count++;
            continue;
          } if (iter_char == '(' || iter_char == '{') {
            bracket_count--;
            continue;
          }
          if (bracket_count > 0)
            continue;
          if (bracket_count < 0) {
            fragments += symbol_read;
            symbol_read = "";
            break;
          }

          while (iter_char.isspace()) { // Ignore whitespaces
            iter.backward_char();
            iter_char = iter.get_char();
          }
          while (iter_char.isalnum() || iter_char == '_') { // Read symbol name
            symbol_read = iter_char.to_string() + symbol_read;
            iter.backward_char();
            iter_char = iter.get_char();
          }
          while (iter_char.isspace()) { // Ignore whitespaces
            iter.backward_char();
            iter_char = iter.get_char();
          }

          if (iter_char == '.') {
            fragments += symbol_read;
            symbol_read = "";
          } else {
            fragments += symbol_read;
            break;
          }
        }

        var keywords = new string[]{"if", "else", "for", "foreach", "while", "do"};
        while (fragments.length > 0 && fragments[fragments.length-1] in keywords) {
            stdout.printf ("cut1\n");
            fragments = fragments[0:fragments.length-1];
        }


        string[] new_fragments = new string[0];
        for (int i = 0; i < fragments.length; i++) {
            if (i == 0 || (fragments[i] != "" && !(fragments[i] in keywords)))
                new_fragments += fragments[i];
        }
        fragments = new_fragments;

        stdout.printf("#######\n");
        foreach (var s in fragments)
            stdout.printf (s + "\n");


        /*TextIter match_sem;
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

        completion_line = iter.get_line() + 1;
        completion_col = iter.get_line_offset();
        completion_stmt = srcbuffer.get_text (match_sem, iter, false).replace("\n", ""); */

        var props_list = new GLib.List<Gtk.SourceCompletionItem>();

        //if (completion_stmt.strip().length > 1) {
        if (fragments.length > 0 && fragments[fragments.length-1].length > 0) {

            string[] serialized_proposals = new string[0];
            try {
                if (main_widget.code_context_provider.daemon != null)
                    //serialized_proposals = main_widget.code_context_provider.daemon.completion (member.file.get_abs(), completion_line, completion_col, completion_stmt);
                    serialized_proposals = main_widget.code_context_provider.daemon.completion_simple (member.file.get_abs(), completion_line, completion_col, fragments);
            } catch (IOError e) {
                stderr.printf ("%s\n", e.message);
            } catch {}

            foreach (var serialized_proposal in serialized_proposals) {

                var proposal = new CompletionProposal.deserialize(serialized_proposal);

                Gdk.Pixbuf pixbuf = main_widget.icon_provider.get_pixbuf_for_symbol (proposal.symbol_type);

                var item = new ComplItem (proposal.symbol_name,
                                        proposal.symbol_name,
                                        pixbuf,
                                        null,
                                        proposal);
                props_list.append (item);
            }
        }

        context.add_proposals (this, props_list, true);

        /*try {
            new Thread<void*>.try ("Completion", () => {
                return null;
            });
        } catch (GLib.Error e) {
            Guanako.errmsg (_("Could not launch completion thread successfully: %s\n"), e.message);
        }*/
    }

    public unowned Gdk.Pixbuf? get_icon() {
        /*if (this.icon == null) {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default();
            try {
                this.icon = theme.load_icon ("dialog-information", 16, 0);
            } catch (GLib.Error e) {
                Guanako.errmsg (_("Could not load theme icon: %s\n"), e.message);
            }
        }
        return this.icon;*/
        return null;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {
        var prop = ((ComplItem)proposal).proposal;

        // Count backward from completion_mark instead of iter (avoids wrong insertion if the user is typing fast)
        TextIter start;
        srcbuffer.get_iter_at_mark (out start, completion_mark);
        start.backward_chars (prop.replace_length);

        srcbuffer.delete (ref start, ref iter);
        srcbuffer.insert (ref start, prop.symbol_name, prop.symbol_name.length);

        // After activating a proposal, immediately queue a new completion request (to keep the completion window open)
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
        return null;//box_info_frame;
    }

    public int get_interactive_delay() {
        return -1;
    }

    public bool get_start_iter (Gtk.SourceCompletionContext context, Gtk.SourceCompletionProposal proposal, out Gtk.TextIter iter) {	
        var mark = srcbuffer.get_insert();
        TextIter cursor_iter;
        srcbuffer.get_iter_at_mark (out cursor_iter, mark);

        var prop = ((ComplItem)proposal).proposal;
        cursor_iter.backward_chars (prop.replace_length);
        iter = cursor_iter;
        return true;
    }

    public void update_info (Gtk.SourceCompletionProposal proposal,
                             Gtk.SourceCompletionInfo info) {
        /*if (info_inner_widget != null) {
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
                             // TRANSLATORS:
                             // Returns a return value (programming).
            vbox.pack_start (new Label (_("Parameters:\n%s\n\nReturns:\n%s").printf(param_string,mth.return_type.data_type.name)));
            info_inner_widget = vbox;
        } else
            info_inner_widget = new Label (prop.symbol.name);

        info_inner_widget.show_all();
        box_info_frame.pack_start (info_inner_widget, true, true);*/
    }
}

/**
 * {@link Gtk.SourceCompletionItem} enhanced to carry a reference to the
 * corresponding Guanako proposal.
 */
class ComplItem : SourceCompletionItem {
    public ComplItem (string label, string text, Gdk.Pixbuf? icon, string? info, CompletionProposal proposal) {
        Object (label: label, text: text, icon: icon, info: info);
        this.proposal = proposal;
    }
    public CompletionProposal proposal;
}
//}
// vim: set ai ts=4 sts=4 et sw=4
