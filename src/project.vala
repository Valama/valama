using Vala;
using GLib;
using Gee;

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

    public Gee.ArrayList<string> packages = new Gee.ArrayList<string>();

    public string build(){
        string ret;
        GLib.Process.spawn_command_line_sync("sh -c 'cd " + project_path + " && mkdir -p build && cd build && cmake .. && make'", null, out ret);
        return ret;
    }
}
