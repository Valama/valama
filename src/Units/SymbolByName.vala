using Vala;

namespace CodeContextHelpers {

  public class SymbolByName : CodeVisitor {
    public SymbolByName () {
      
    }

    bool found = false;
    string full_name = null;
    Symbol result = null;
    public Symbol? get_symbol_by_full_name (Vala.Symbol root, string full_name) {
      found = false;
      this.full_name = full_name;
      result = null;
      root.accept (this);
      return result;
    }

    public override void visit_namespace (Vala.Namespace ns) {
      if (found) return;
      if (ns.parent_node == null) {
        ns.accept_children (this);
      } else {
        if (ns.get_full_name() == full_name) {
          result = ns;
          found = true;
        } else
          ns.accept_children (this);
      }
    }
    public override void visit_class (Vala.Class cl) {
      if (found) return;
      if (cl.get_full_name() == full_name) {
        result = cl;
        found = true;
      } else
        cl.accept_children (this);
    }


  }

}
