using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    public static ProjectMember? createTarget(Project.Project project) {
      var member = new ProjectMemberTarget();
      member.project = project;

      member.binary_name = "NewTarget";
      member.buildsystem = Builder.EnumBuildsystem.CUSTOM;
      return member;
    }

  }

}
