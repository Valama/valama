using Gtk;
using Vala;
using GLib;

public class valama_project{
    public valama_project(string project_path){
        this.project_path = project_path;
        guanako_project = new Guanako.project();

        var directory = File.new_for_path (project_path + "/src");

        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

        SourceFile[] sf = new SourceFile[0];
        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            string file = project_path + "/src/" + file_info.get_name ();
            if (file.has_suffix(".vala")){
                stdout.printf(@"Found file $file\n");
                var source_file = new SourceFile (guanako_project.code_context, SourceFileType.SOURCE, file);
                guanako_project.add_source_file (source_file);
                sf += source_file;
            }
        }
        source_files = sf;
        
        guanako_project.add_package ("gobject-2.0");
        guanako_project.add_package ("glib-2.0");
        guanako_project.add_package ("gio-2.0");
        guanako_project.add_package ("gee-1.0");
        guanako_project.add_package ("libvala-0.16");
        guanako_project.add_package ("gdk-3.0");
        guanako_project.add_package ("gtk+-3.0");
        guanako_project.add_package ("gtksourceview-3.0");

        guanako_project.update();
    }
    
    public SourceFile[] source_files;
    public Guanako.project guanako_project;
    string project_path;
    
    public string build(){
    	string ret;
    	GLib.Process.spawn_command_line_sync("sh -c 'cd " + project_path + " && mkdir build && cd build && cmake .. && make'", out ret);
    	return ret;
    }
}

public class project_browser {
    public project_browser(valama_project project){
        this.project = project;

        tree_view = new TreeView ();

        build();

        var scrw = new ScrolledWindow(null, null);
        scrw.add(tree_view);
        scrw.set_size_request(200,0);
        widget = scrw;
    }

    valama_project project;
    TreeView tree_view;
    public Widget widget;

    public signal void source_file_selected(SourceFile file);

    void build(){
        var store = new TreeStore (2, typeof (string), typeof (string));
        tree_view.set_model (store);

        tree_view.insert_column_with_attributes (-1, "Symbol", new CellRendererText (), "text", 0, null);
        //tree_view.insert_column_with_attributes (-1, "Type", new CellRendererText (), "text", 1, null);

        TreeIter iter_source_files;
        store.append (out iter_source_files, null);
        store.set (iter_source_files, 0, "Sources", -1);
        
        foreach (SourceFile sf in project.source_files){
            TreeIter iter_sf;
            store.append (out iter_sf, iter_source_files);
            var name = sf.filename.substring(sf.filename.last_index_of("/") + 1);
            store.set (iter_sf, 0, name, 1, "", -1);
        }
        
        tree_view.row_activated.connect((path)=>{
            int[] indices = path.get_indices();
            if (indices.length > 1){
                source_file_selected(project.source_files[indices[1]]);
            }
        });

   }
}
