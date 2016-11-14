namespace Builder {

  public class Helper {
    public static void write_gresource_xml (Project.ProjectMemberGResource member, string path) throws Error {
      var file = File.new_for_path (path);
      if (file.query_exists ())
        file.delete ();

      var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
      dos.put_string ("""<?xml version="1.0" encoding="UTF-8"?>""" + "\n");
      dos.put_string ("""<gresources>""" + "\n");
      dos.put_string ("""<gresource prefix="/">""" + "\n");
      
      foreach (var res in member.resources) {
        dos.put_string ("""<file>""" + res.file.get_rel() + """</file>""" + "\n");
      }

      dos.put_string ("""</gresource>""" + "\n");
      dos.put_string ("""</gresources>""" + "\n");    
    }

    public static void write_gladeui_gresource_xml (Project.ProjectMemberTarget target, string path) throws Error {
      var file = File.new_for_path (path);
      if (file.query_exists ())
        file.delete ();

      var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));
      dos.put_string ("""<?xml version="1.0" encoding="UTF-8"?>""" + "\n");
      dos.put_string ("""<gresources>""" + "\n");
      dos.put_string ("""<gresource prefix="/">""" + "\n");

      foreach (var id in target.included_gladeuis) {
        var gladeui = target.project.getMemberFromId(id) as Project.ProjectMemberGladeUi;
        dos.put_string ("""<file>""" + gladeui.file.get_rel() + """</file>""" + "\n");
      }

      dos.put_string ("""</gresource>""" + "\n");
      dos.put_string ("""</gresources>""" + "\n");
    }

    public static void write_config_vapi (Project.ProjectMemberTarget target, string path) throws Error {
      var vapi = File.new_for_path (path);
      if (vapi.query_exists ())
        vapi.delete ();
      var dos = new DataOutputStream (vapi.create (FileCreateFlags.REPLACE_DESTINATION));
      dos.put_string ("""[CCode (cprefix = "", lower_case_cprefix = "")]""" + "\n");
      dos.put_string ("namespace Config {\n");

      foreach (string id in target.included_data) {
        var data = target.project.getMemberFromId (id) as Project.ProjectMemberData;
        dos.put_string ("  public const string " + data.basedir + ";\n");
      }

      dos.put_string ("  public const string GETTEXT_PACKAGE_DOMAIN;\n");
      dos.put_string ("}\n");
    }


    // Recursive copying
    // From http://stackoverflow.com/questions/16453739/how-do-i-recursively-copy-a-directory-using-vala
    public static bool copy_recursive (GLib.File src, GLib.File dest, GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE, GLib.Cancellable? cancellable = null) throws GLib.Error {
      GLib.FileType src_type = src.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);
      if (src_type == GLib.FileType.DIRECTORY ) {
        if (!dest.query_exists())
          dest.make_directory (cancellable);
        src.copy_attributes (dest, flags, cancellable);

        string src_path = src.get_path ();
        string dest_path = dest.get_path ();
        GLib.FileEnumerator enumerator = src.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE, cancellable);
        for ( GLib.FileInfo? info = enumerator.next_file (cancellable) ; info != null ; info = enumerator.next_file (cancellable) ) {
          copy_recursive (
            GLib.File.new_for_path (GLib.Path.build_filename (src_path, info.get_name ())),
            GLib.File.new_for_path (GLib.Path.build_filename (dest_path, info.get_name ())),
            flags,
            cancellable);
        }
      } else if ( src_type == GLib.FileType.REGULAR ) {
        src.copy (dest, flags, cancellable);
      }

      return true;
    }


  }

}
