using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    public static ProjectMember? createData(Project.Project project) {
      var member = new ProjectMemberData();
      member.project = project;

      member.name = "New data";
      member.basedir = "BASE_DIR";
      return member;
    }

  }

}
