namespace Units {

  /*
   * Tracks cmake targets, writes the CMakeLists.txt
   */

  public class CMakeSwitchWriter : Unit {
    
    public override void init() {
      // Track all existing and new targets
      foreach (var member in main_widget.project.members) {
        if (member is Project.ProjectMemberTarget) {
          var target_member = member as Project.ProjectMemberTarget;
          setup_target (target_member);
        }
      }
      main_widget.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberTarget) {
          var target_member = member as Project.ProjectMemberTarget;
          setup_target (target_member);
          write();
        }
      });
      main_widget.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberTarget) {
          var target_member = member as Project.ProjectMemberTarget;
          write();
        }
      });
    }


    // Write switch whenever a different builder is chosen
    private void setup_target (Project.ProjectMemberTarget member) {
      member.builder_changed.connect (()=>{
        write();
      });
    }

    // Write a CMakeLists.txt that allows switching between targets
    private void write() {
      var file = File.new_for_path ("CMakeLists.txt");
      if (file.query_exists ())
          file.delete ();
      var dos = new DataOutputStream (file.create (FileCreateFlags.REPLACE_DESTINATION));

      // If only one CMake target exists, set it as default
      string first_name = "";
      foreach (var member in main_widget.project.members) {
        if (!(member is Project.ProjectMemberTarget))
          continue;
        var target_member = member as Project.ProjectMemberTarget;
        if (target_member.buildsystem == Builder.EnumBuildsystem.CMAKE) {
          if (first_name != "") {
            first_name = "";
            break;
          }
          first_name = target_member.binary_name;
        }
      }

      dos.put_string ("cmake_minimum_required(VERSION \"2.8.4\")\n\n");
      dos.put_string ("set(TARGET \"" + first_name + "\" CACHE STRING \"Target\")\n");
      dos.put_string ("set(target_specified FALSE)\n");

      // Build switch for every CMake target
      foreach (var member in main_widget.project.members) {
        if (!(member is Project.ProjectMemberTarget))
          continue;
        var target_member = member as Project.ProjectMemberTarget;
        if (target_member.buildsystem == Builder.EnumBuildsystem.CMAKE) {
          dos.put_string ("if (\"${TARGET}\" STREQUAL \"" + target_member.binary_name + "\")\n");
          dos.put_string ("  include(\"CMake_" + target_member.binary_name + ".txt\")\n");
          dos.put_string ("  set(target_specified TRUE)\n");
          dos.put_string ("endif ()\n");
        }
      }
      dos.put_string ("if (NOT target_specified)\n");
      dos.put_string ("  message( FATAL_ERROR \"Specify a target via 'cmake -DTARGET=my_target ...'\" )\n");
      dos.put_string ("endif ()");
    }

    public override void destroy() {
    }

 }

}
