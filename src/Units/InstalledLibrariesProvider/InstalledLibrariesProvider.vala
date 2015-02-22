
/*
  Unit:         InstalledLibrariesProvider
  Purpose:      Provide list of installed libraries
  Unit deps:    none
*/

namespace Units {

  public class InstalledLibrariesProvider : Unit {
    
    public struct InstalledLibrary {
      public string library;
      public string description;
    }

    public override void init() {
    }
    public override void destroy() {
    }

    public Gee.TreeSet<InstalledLibrary?> installed_libraries = new Gee.TreeSet<InstalledLibrary?>();
    public void update() {
      installed_libraries = new Gee.TreeSet<InstalledLibrary?>((a,b) => {
        if (a.library > b.library)
          return 1;
        if (a.library < b.library)
          return -1;
        return 0;
      });
    
      // Get pkg-config libraries
      string pkgconfig_out;
      Process.spawn_command_line_sync ("pkg-config --list-all", out pkgconfig_out, null, null);
      var lines = pkgconfig_out.split ("\n");

      // Split it into lib names and descriptions
      foreach (var line in lines) {
        if (line == "")
          continue;

        var linesplit = line.split (" ", 2);

        var lib = new InstalledLibrary();
        lib.library = linesplit[0];
        lib.description = linesplit[1].chug();

        installed_libraries.add (lib);
      }
    }
    

 }

}
