using Gtk;
using Vala;

public class symbol_browser {
    public symbol_browser(Guanako.project project){
        this.project = project;

        tree_view = new TreeView ();

        build();

        widget = tree_view;
    }

    Guanako.project project;
    TreeView tree_view;
    public Widget widget;

    void build(){
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        tree_view.insert_column_with_attributes (-1, "Symbol", new CellRendererText (), "text", 0, null);
        tree_view.insert_column_with_attributes (-1, "Type", new CellRendererText (), "text", 1, null);

        TreeIter category_iter;
        TreeIter[] iters = new TreeIter[0];

        Guanako.iter_symbol (project.root_symbol, (smb, depth)=>{
            if (smb.name != null){

                string tpe = "";
                if (smb is Class)
                    tpe = "Class";
                if (smb is Method)
                    tpe = "Method";
                if (smb is Field)
                    tpe = "Field";
                if (smb is Constant)
                    tpe = "Constant";
                if (smb is Property)
                    tpe = "Property";

                TreeIter next;
                if (depth == 1)
                    store.append (out next, null);
                else
                    store.append (out next, iters[depth - 2]);
                store.set (next, 0, smb.name, 1, tpe, -1);
                if (iters.length - 2 < depth)
                    iters += next;
                else
                    iters[depth] = next;
            }
            return Guanako.iter_callback_returns.continue;
        });
    }
}
