using Project;

namespace Ui {

  namespace ProjectMemberCreator {

    public static ProjectMember? createGResource(Project.Project project) {
      var member = new ProjectMemberGResource();
      member.project = project;

      member.name = "New resource";
      return member;
    }

  }

}
