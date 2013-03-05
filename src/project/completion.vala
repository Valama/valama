/*
 * src/project/completion.vala
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
using Guanako;
using Vala;

static bool parsing = false;

class GuanakoCompletion : Gtk.SourceCompletionProvider, Object {
    Gdk.Pixbuf icon;
    public string name;
    public int priority;
    GLib.List<Gtk.SourceCompletionItem> proposals;

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

    public void populate (Gtk.SourceCompletionContext context) {
        //TODO: Provide way to get completion for not saved content.
        if (source_viewer.current_srcfocus == _("New document"))
            return;

        /* Get current line */
        var mark = source_viewer.current_srcbuffer.get_insert();
        TextIter iter;
        source_viewer.current_srcbuffer.get_iter_at_mark (out iter, mark);
        var line = iter.get_line() + 1;
        var col = iter.get_line_offset();

        TextIter iter_start;
        source_viewer.current_srcbuffer.get_iter_at_line (out iter_start, line - 1);
        var current_line = source_viewer.current_srcbuffer.get_text (iter_start, iter, false);

        if (parsing)
            loop_update.run();

        try {
            new Thread<void*>.try (_("Completion"), () => {
                /* Get completion proposals from Guanako */
                var guanako_proposals = project.guanako_project.propose_symbols (
                            project.guanako_project.get_source_file_by_name (source_viewer.current_srcfocus),
                            line,
                            col,
                            current_line);

                /* Assign icons and pass the proposals on to Gtk.SourceView */
                var props = new GLib.List<Gtk.SourceCompletionItem>();
                foreach (Gee.TreeSet<CompletionProposal> list in guanako_proposals)
                foreach (CompletionProposal guanako_proposal in list) {
                    if (guanako_proposal.symbol.name != null) {

                        Gdk.Pixbuf pixbuf = get_pixbuf_for_symbol (guanako_proposal.symbol);

                        var item = new ComplItem (guanako_proposal.symbol.name,
                                                  guanako_proposal.symbol.name,
                                                  pixbuf,
                                                  null,
                                                  guanako_proposal);
                        props.append (item);
                    }
                }
                GLib.Idle.add (() => {
                    if (context is SourceCompletionContext)
                        context.add_proposals (this, props, true);
                    return false;
                });
                return null;
            });
        } catch (GLib.Error e) {
            errmsg (_("Could not launch completion thread successfully: %s\n"), e.message);
        }
    }

    public unowned Gdk.Pixbuf? get_icon() {
        if (this.icon == null) {
            Gtk.IconTheme theme = Gtk.IconTheme.get_default();
            try {
                this.icon = theme.load_icon (Gtk.Stock.DIALOG_INFO, 16, 0);
            } catch (GLib.Error e) {
                errmsg (_("Could not load icon theme: %s\n"), e.message);
            }
        }
        return this.icon;
    }

    public bool activate_proposal (Gtk.SourceCompletionProposal proposal,
                                   Gtk.TextIter iter) {
        var prop = ((ComplItem)proposal).guanako_proposal;

        TextIter start = iter;
        start.backward_chars (prop.replace_length);

        source_viewer.current_srcbuffer.delete (ref start, ref iter);
        source_viewer.current_srcbuffer.insert (ref start, prop.symbol.name, prop.symbol.name.length);
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
        var mark = source_viewer.current_srcbuffer.get_insert();
        TextIter cursor_iter;
        source_viewer.current_srcbuffer.get_iter_at_mark (out cursor_iter, mark);

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
                param_string = _("none");
            vbox.pack_start (new Label (_("Parameters:\n") + param_string +
                                        _("\n\nReturns:\n") +
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

// vim: set ai ts=4 sts=4 et sw=4
