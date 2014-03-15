using Gtk;

namespace WelcomeScreen {
    protected class CreateProjectPackages : TemplatePageWithHeader {
        public CreateProjectPackages (ref ProjectCreationInfo info)
        {
            this.info = info;
            listmodel = new ListStore (3, typeof (bool), typeof (string), typeof (string));
            go_to_next_clicked.connect (() => {
                var pkgs = new string[0];
                listmodel.foreach((m,p,i) => {
                    Value v1, v2;
                    m.get_value(i, 0, out v1);
                    m.get_value(i, 1, out v2);
                    if((bool)v1)
                        pkgs += (string)v2;
                    return false;
                });
                this.info.packages = pkgs;
            });
        }
        
        private ProjectCreationInfo info;
        ListStore listmodel;
    
        protected override void clean_up(){}
        
      
        
        protected override Gtk.Widget build_inner_widget() {
            heading = _("Choose packages");
            description = _("packages for current project");
            
            var frame = new Frame (null);
            var sw = new ScrolledWindow (null, null);
            frame.add (sw);
            var tree_view = new TreeView();
            tree_view.set_model (listmodel);
            CellRendererToggle toggle = new CellRendererToggle();
            toggle.toggled.connect ((toggle, path) => {
                TreePath tree_path = new TreePath.from_string (path);
                TreeIter iter;
                listmodel.get_iter (out iter, tree_path);
                listmodel.set (iter, 0, !toggle.active);
            });
            TreeViewColumn column = new TreeViewColumn();
            column.pack_start (toggle, false);
            column.add_attribute (toggle, "active", 0);
            tree_view.append_column (column);
            
            CellRendererText text = new CellRendererText();
            column = new TreeViewColumn();
            column.title = "Package";
            column.pack_start (text, true);
            column.add_attribute (text, "text", 1);
            tree_view.append_column (column);
            
            CellRendererText desc_text = new CellRendererText();
            column = new TreeViewColumn();
            column.title = "Description";
            column.pack_start (desc_text, true);
            column.add_attribute (desc_text, "text", 2);
            tree_view.append_column (column);
            
            var pkg_infos = list_all_pkg_config();
            
            pkg_infos.foreach (entry => {
                if (info.template.vproject.packages.has_key (entry.key))
                    return true;
                TreeIter iter;
                listmodel.append (out iter);
                listmodel.set (iter, 0, false, 1, entry.key, 2, entry.value);
                return true;
            }); 
            sw.add (tree_view); 
            return frame;
        }
    }
}
