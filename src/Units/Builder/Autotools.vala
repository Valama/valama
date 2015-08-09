namespace Builder {
  public class Autotools : Builder {
    public override Gtk.Widget? init_ui() {
      return null;
    }
    
    public override void set_defaults() {
    }
    
    public override void load (Xml.Node* node) {
    }
    
    public override void save (Xml.TextWriter writer) {
    }
    
    public override bool can_export () {
      return false;
    }
    
    public override void export (Ui.MainWidget main_widget) {

    }
    
    void create_if_not_exists (string filename) {
      if (FileUtils.test (filename, FileTest.EXISTS)) {
        if (FileUtils.test (filename, FileTest.IS_DIR))
          File.new_for_path (filename).delete();
      }
      else
        File.new_for_path (filename).create (FileCreateFlags.NONE);
    }
    
    void create_authors (Project.ProjectMemberInfo? info) {
      var file = File.new_for_path ("AUTHORS");
      if (file.query_exists())
        file.delete();
      var dos = new DataOutputStream (file.create (FileCreateFlags.NONE));
      if (info == null)
        dos.put_string ("Unknown <unknown@dummy.com>\n");
      else
        foreach (var author in info.authors)
          dos.put_string ("%s <%s>\n".printf (author.name, author.mail));
    }
    
    public override void build (Ui.MainWidget main_widget) {
      // Create build directory if not existing yet
      DirUtils.create_with_parents ("build", 509);
      
      Project.ProjectMemberInfo info = null;
      foreach (var pm in target.project.members) {
        if (pm is Project.ProjectMemberInfo) {
          info = pm as Project.ProjectMemberInfo;
          break;
        }
      }
      
      state = BuilderState.COMPILING;
      
      create_if_not_exists ("NEWS");
      create_if_not_exists ("README");
      create_if_not_exists ("ChangeLog");
      create_authors (info);
      
      var file = File.new_for_path ("m4");
      if (!FileUtils.test ("m4", FileTest.IS_DIR) && file.query_exists())
        file.delete();
      DirUtils.create_with_parents ("m4", 509);
      
      file = File.new_for_path ("autogen.sh");
      if (file.query_exists())
        file.delete();
      var stream = new DataOutputStream (file.create (FileCreateFlags.NONE));
      stream.put_string ("#!/bin/sh\n\n");
      stream.put_string ("test -n \"$srcdir\" || srcdir=`dirname \"$0\"`\n\n");
      stream.put_string ("autoreconf -f -i -s $srcdir\n\n");
      Process.spawn_command_line_sync ("chmod +x autogen.sh");
      
      string version = "0.1";
      string mail = "null@dummy.com";
      if (info != null) {
        version = "%d.%d".printf (info.major, info.minor);
        if (info.authors.size > 0)
          mail = info.authors[0].mail;
      }
      string name = target.binary_name;
      string gir_name = "";
      foreach (var n in name.split ("-")) {
        if (n.length == 0)
          continue;
        gir_name += n[0].toupper().to_string();
        if (n.length == 1)
          continue;
        gir_name += n.substring (1);
      }
      gir_name += "-" + version;
      string cname = target.binary_name.replace ("-", "_");
      
      file = File.new_for_path ("configure.ac");
      if (file.query_exists())
        file.delete();
      stream = new DataOutputStream (file.create (FileCreateFlags.NONE));
      stream.put_string (@"AC_INIT([$cname], [$version], [$mail], [$cname])\n");
      stream.put_string ("AC_CONFIG_MACRO_DIR([m4])\n");
      stream.put_string ("AM_INIT_AUTOMAKE\n");
      stream.put_string ("AC_CONFIG_FILES([Makefile\n");
      stream.put_string ("])\n\n");
      stream.put_string ("AM_PROG_AR\n");
      stream.put_string ("LT_INIT\n");
      stream.put_string ("AC_PROG_CC\n");
      stream.put_string ("AM_PROG_VALAC\n\n");
      
      string packages = "";
      if (target.metadependencies.size == 0)
        packages = "gobject-2.0";
      foreach (var meta_dep in target.metadependencies)
        foreach (var dep in meta_dep.dependencies)
          if (dep.type == Project.DependencyType.PACKAGE)
            packages += dep.library;
      
      stream.put_string (@"PKG_CHECK_MODULES($(name.up()), [$packages])\n");
      stream.put_string (@"AC_SUBST($(cname.up())_CFLAGS)\n");
      stream.put_string (@"AC_SUBST($(cname.up())_LIBS)\n");

      if (target.library)
        stream.put_string ("GOBJECT_INTROSPECTION_CHECK([0.9.0])\n");

      stream.put_string ("AC_OUTPUT\n");
      
      file = File.new_for_path ("Makefile.am");
      if (file.query_exists())
        file.delete();
      stream = new DataOutputStream (file.create (FileCreateFlags.NONE));
      
      string libname = (name.has_prefix ("lib") ? name : "lib" + name) + "-" + version;
      if (target.library)
        stream.put_string ("lib_LTLIBRARIES = %s.la\n\n".printf (libname));
      else
        stream.put_string ("bin_PROGRAMS = %s\n\n".printf (name));
      
      if (target.library) {
        stream.put_string ("vapidir = $(datadir)/vala/vapi\n");
        stream.put_string ("dist_vapi_DATA = $(srcdir)/%s.vapi\n\n".printf (name));
        stream.put_string ("%sincludedir = $(includedir)\n".printf (cname));
        stream.put_string ("%sinclude_HEADERS = $(srcdir)/%s.h\n\n".printf (cname, name));
      }
      
      uint data_index = 0;
      foreach (string id in target.included_data) {
        var data = target.project.getMemberFromId (id) as Project.ProjectMemberData;
        foreach (var tg in data.targets) {
          stream.put_string ("%s%udir = $(datadir)%s\n".printf (data.name, data_index, tg.target));
          stream.put_string ("dis_%s%u_DATA = %s\n".printf (data.name, data_index, tg.file));
          data_index++;
        }
        stream.put_string ("\n");
      }
      
      string gresource_name = null;
      
      if (target.included_gresources.size > 0) {
        string ui_data = "ui_data = ";
        var gresource = target.project.getMemberFromId (target.included_gresources[0]) as Project.ProjectMemberGResource;
        gresource_name = gresource.name;
        foreach (var res in gresource.resources)
          ui_data += "%s ".printf (res.file.get_rel());
        ui_data += "\n\n";
        stream.put_string (ui_data);
        stream.put_string ("%s.xml:\n".printf (gresource.name));
        stream.put_string ("\techo '<?xml version=\"1.0\" encoding=\"UTF-8\"?>' > $@\n");
        stream.put_string ("\techo '<gresources prefix=\"/\">' >> $@\n");
        stream.put_string ("\t$(foreach ui, $(ui_data), echo '    <file compressed=\"%s\" >$(ui)</file>' >> $@;)\n");
        stream.put_string ("\techo '  </gresource>' >> $@\n");
        stream.put_string ("\techo '</gresources>' >> $@\n\n");
        stream.put_string ("ui.c: %s.xml\n".printf (gresource.name));
        stream.put_string ("\tglib-compile-resources $^ --sourcedir=$(srcdir) --generate-source --target=$@\n\n");
      }
    
      string lowname = target.library ? libname.replace ("-", "_").replace (".", "_") + "_la": cname;
      stream.put_string ("%s_CFLAGS = $(%s_CFLAGS)\n".printf (lowname, cname.up()));
      if (target.library) {
        stream.put_string ("%s_LIBADD = $(%s_LIBS)\n".printf (lowname, cname.up()));
        stream.put_string ("%s_LDFLAGS = -version-info %d:%d:%d\n".printf (lowname, info.major, info.minor, info.patch));
      }
      else
        stream.put_string ("%s_LDADD = $(%s_LIBS)\n".printf (lowname, cname.up()));
      
      stream.put_string ("%s_VALAFLAGS = ".printf (lowname));
      if (target.library)
        stream.put_string ("--library %s -H %s.h --gir %s.gir --vapi %s.vapi ".printf (name, name, gir_name, name));
      if (gresource_name != null)
        stream.put_string ("--gresources %s.xml --target-glib=2.38 ".printf (gresource_name));
      if (target.metadependencies.size == 0)
        stream.put_string ("--pkg gobject-2.0 ");
      foreach (var meta_dep in target.metadependencies)
        foreach (var dep in meta_dep.dependencies)
          if (dep.type == Project.DependencyType.PACKAGE)
            stream.put_string ("--pkg %s ".printf (dep.library));
          else {
            var vapi_file = File.new_for_path (dep.library);
            stream.put_string ("--vapidir %s ".printf (vapi_file.get_parent().get_path()));
            stream.put_string ("--pkg %s ".printf (vapi_file.get_basename().replace(".vapi", "")));
          }
      foreach (var def in target.defines)
        stream.put_string ("--define %s ".printf (def.define));
      stream.put_string ("\n\n");
      stream.put_string ("%s_SOURCES = ".printf (lowname));
      foreach (string id in target.included_sources) {
        var source = target.project.getMemberFromId (id) as Project.ProjectMemberValaSource;
        stream.put_string ("%s ".printf (source.file.get_rel()));
      }
      stream.put_string ("\n\n");
      if (target.library)
        stream.put_string ("""if HAVE_INTROSPECTION
girdir = @INTROSPECTION_GIRDIR@

gir_DATA = \
  $(srcdir)/%s.gir \
  $(NULL)

typelibdir = @INTROSPECTION_TYPELIBDIR@
typelib_DATA = \
  %s.typelib \
  $(NULL)

%s.typelib: $(srcdir)/%s.gir
  @INTROSPECTION_COMPILER@ --shared-library=%s.so.0 -o $@ $^
endif""".printf (gir_name, gir_name, gir_name, gir_name, libname));
      stream.put_string ("\n");
      stream.put_string ("CLEANFILES = *.c *.o %s *.stamp\n".printf (target.library ? libname + ".*" : name));
      stream.put_string ("DISTCLEANFILES = $(CLEANFILES) Makefile.in\n");
      
      ulong process_exited_handler = 0;
      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
      
      var project_dir = File.new_for_path (target.project.filename).get_parent().get_path();
      Pid child_pid = main_widget.console_view.spawn_process ("/bin/sh -c \"cd '" + project_dir + "/build' && ../autogen.sh && ../configure && make\"", build_dir + "/build");
    }
    
    Pid run_pid;
    
    public override void run (Ui.MainWidget main_widget) {
      var build_dir = "build/";
      run_pid = main_widget.console_view.spawn_process (build_dir + target.binary_name);

      state = BuilderState.RUNNING;

      ulong process_exited_handler = 0;
      process_exited_handler = main_widget.console_view.process_exited.connect (()=>{
        state = BuilderState.COMPILED_OK;
        main_widget.console_view.disconnect (process_exited_handler);
      });
    }
    
    public override void abort_run() {
      Posix.kill (run_pid, 15);
      Process.close_pid (run_pid);
    }

    public override void clean() {

    }
  }
}
