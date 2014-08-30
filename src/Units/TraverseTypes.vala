using Vala;

namespace CodeContextHelpers {

  public class TraverseTypes : CodeVisitor {
    public TraverseTypes () {
      
    }

    public delegate void DelegateTraversed (Vala.Symbol symbol);

    DelegateTraversed traversed = null;
    public void traverse (Vala.Symbol root, DelegateTraversed traversed) {
      this.traversed = traversed;
      root.accept (this);
    }

    public override void visit_namespace (Vala.Namespace ns) {
      if (ns.parent_node == null) {
        ns.accept_children (this);
      } else {
        traversed (ns);
        ns.accept_children (this);
      }
    }
    public override void visit_class (Vala.Class cl) {
      traversed (cl);
      cl.accept_children (this);
    }


  }

}
