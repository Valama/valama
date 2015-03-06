
namespace Project {

  public class FileRef {
    private File file;
    private Project project;
    public FileRef.from_abs (Project project, string abs_path) {
      this.project = project;
      file = File.new_for_path (abs_path);
    }
    public FileRef.from_rel (Project project, string rel_path) {
      this.project = project;
      var proj_dir = File.new_for_path (project.filename).get_parent();
      file = proj_dir.resolve_relative_path (rel_path);
    }
    public FileRef.from_file (Project project, File file) {
      this.project = project;
      this.file = file;
    }
    public File get_file() {
      return file;
    }
    public string get_abs() {
      return file.get_path();
    }
    public string get_rel() {
      var proj_dir = File.new_for_path (project.filename).get_parent();
      return proj_dir.get_relative_path (file);
    }
  }

}

