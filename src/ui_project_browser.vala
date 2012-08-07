using Gtk;
using Vala;

public class valama_project{
    public valama_project(string project_path){

        guanako_project = new Guanako.project();

        var directory = File.new_for_path (project_path + "/src");

        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

        main_file = null;

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
        guanako_project.update();
    }
    
    public SourceFile[] source_files;
    public Guanako.project guanako_project;
    
}

public class project_browser {
    public project_browser(valama_project project){
        this.project = project;

        tree_view = new TreeView ();

        build();

        widget = tree_view;
    }

    valama_project project;
    TreeView tree_view;
    public Widget widget;

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
            store.set (iter_sf, 0, sf.filename, 1, "", -1);
        }

   }
}
