/*
 * guanako/guanako_iterators.vala
 * Copyright (C) 2012, 2013, Valama development team
 *
 * Valama is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Valama is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;
using Vala;

namespace Guanako {

    private Vala.List<Symbol>[] get_child_symbols_of_type (Symbol smb, string type) {
        var ret = new Vala.List<Symbol>[0];

        if (smb is Class) {
            //If parent is a Class, add its base class and types (i.e. interfaces it implements etc)
            var p = (Class) smb;
            if (p.base_class != null) {
                var base_ret = get_child_symbols_of_type (p.base_class, type);
                foreach (Vala.List<Symbol> list in base_ret)
                    ret += list;
            }
            foreach (DataType p_type in p.get_base_types()) {
                var base_ret = get_child_symbols_of_type (p_type.data_type, type);
                foreach (Vala.List<Symbol> list in base_ret)
                    ret += list;
            }
        }
        var main_res = get_child_symbols_of_type_simple (smb, type);
        if (main_res != null)
            ret += main_res;
        return ret;
    }

    private Vala.List<Symbol>? get_child_symbols_of_type_simple (Symbol smb, string type) {
        if (smb is Namespace) {
            var cv = (Namespace) smb;
            if (type == "Namespace")
                return cv.get_namespaces();
            if (type == "Constant")
                return cv.get_constants();
            if (type == "Enum")
                return cv.get_enums();
            if (type == "ErrorDomain")
                return cv.get_error_domains();
            if (type == "Struct")
                return cv.get_structs();
            if (type == "Interface")
                return cv.get_interfaces();
            if (type == "Class")
                return cv.get_classes();
            if (type == "Field")
                return cv.get_fields();
            if (type == "Delegate")
                return cv.get_delegates();
            if (type == "Method")
                return cv.get_methods();
        }
        if (smb is Class) {
            var cv = (Class) smb;
            if (type == "Constant")
                return cv.get_constants();
            if (type == "Enum")
                return cv.get_enums();
            if (type == "Struct")
                return cv.get_structs();
            if (type == "Class")
                return cv.get_classes();
            if (type == "Field")
                return cv.get_fields();
            if (type == "Delegate")
                return cv.get_delegates();
        }
        if (smb is Enum) {
            var cv = (Enum) smb;
            if (type == "Constant")
                return cv.get_constants();
            if (type == "Method")
                return cv.get_methods();
        }
        if (smb is ErrorDomain) {
            var cv = (ErrorDomain) smb;
            if (type == "ErrorCode")
                return cv.get_codes();
            if (type == "Method")
                return cv.get_methods();
        }
        if (smb is Interface) {
            var cv = (Interface) smb;
            if (type == "Constant")
                return cv.get_constants();
            if (type == "Enum")
                return cv.get_enums();
            if (type == "Struct")
                return cv.get_structs();
            if (type == "Class")
                return cv.get_classes();
            if (type == "Field")
                return cv.get_fields();
            if (type == "Delegate")
                return cv.get_delegates();
        }
        if (smb is Struct) {
            var cv = (Struct) smb;
            if (type == "Constant")
                return cv.get_constants();
            if (type == "Property")
                return cv.get_properties();
            if (type == "Field")
                return cv.get_fields();
            if (type == "Method")
                return cv.get_methods();
        }
        if (smb is ObjectTypeSymbol) {
            var cv = (ObjectTypeSymbol) smb;
            if (type == "Property")
                return cv.get_properties();
            if (type == "Method")
                return cv.get_methods();
            if (type == "Signal")
                return cv.get_signals();
            if (type == "CreationMethod") {
                var ret = new Vala.ArrayList<Symbol>();
                foreach (Symbol m in cv.get_methods())
                    if (m is CreationMethod)
                        ret.add (m);
                return ret;
            }
        }
        return null;
    }

    /*
     * Get parent's children.
     */
    Gee.LinkedList<Symbol> get_child_symbols (Symbol parent) {
        var ret = new Gee.LinkedList<Symbol>();
        if (parent is Class) {
            //If parent is a Class, add its base class and types (i.e. interfaces it implements etc)
            var p = (Class) parent;
            if (p.base_class != null)
                ret = get_child_symbols (p.base_class);
            foreach (DataType type in p.get_base_types()) {
                iter_symbol (type.data_type, (s, depth) => {
                    if (depth == 0)
                        return IterCallbackReturns.CONTINUE;
                    ret.add(s);
                    return IterCallbackReturns.ABORT_BRANCH;
                });
            }
        }

        iter_symbol (parent, (s, depth) => {
            if (depth == 0)
                return IterCallbackReturns.CONTINUE;
            ret.add(s);
            return IterCallbackReturns.ABORT_BRANCH;
        });
        return ret;
    }

    /**
     * Find {@link Vala.Symbol}'s {@link Vala.Namespace}.
     */
    public Namespace? get_parent_namespace (Symbol smb) {
        for (var iter = smb; iter != null; iter = iter.parent_symbol)
            if (iter is Namespace)
                return (Namespace) iter;
        return null;
    }

    public class SymbolVisitor : CodeVisitor {
        public SymbolVisitor (iter_callback callback) {
            this.callback = callback;
        }
        iter_callback callback;
        bool abort_tree = false;
        public override void visit_source_file (SourceFile source_file) {
            source_file.accept_children (this);
        }
        public override void visit_namespace  (Vala.Namespace ns) {
            if (abort_tree)
                return;
            var ret = callback (ns, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                ns.accept_children(this);
        }
        public override void visit_class (Class cl) {
            if (abort_tree)
                return;
            var ret = callback (cl, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                cl.accept_children(this);
        }
        public override void visit_struct (Struct st) {
            if (abort_tree)
                return;
            var ret = callback (st, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                st.accept_children(this);
        }
        public override void visit_interface (Interface iface) {
            if (abort_tree)
                return;
            var ret = callback (iface, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                iface.accept_children(this);
        }
        public override void visit_enum (Vala.Enum en) {
            if (abort_tree)
                return;
            var ret = callback (en, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                en.accept_children(this);
        }
        public override void visit_error_domain (ErrorDomain edomain) {
            if (abort_tree)
                return;
            var ret = callback (edomain, 0);
            if (ret == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
            else if (ret == IterCallbackReturns.CONTINUE)
                edomain.accept_children(this);
        }
        public override void visit_enum_value (Vala.EnumValue ev) {
            if (abort_tree)
                return;
            if (callback (ev, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_error_code (ErrorCode ecode) {
            if (abort_tree)
                return;
            if (callback (ecode, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_delegate (Delegate d) {
            if (abort_tree)
                return;
            if (callback (d, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_signal (Vala.Signal sig) {
            if (abort_tree)
                return;
            if (callback (sig, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_field (Field f) {
            if (abort_tree)
                return;
            if (callback (f, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_constant (Constant c) {
            if (abort_tree)
                return;
            if (callback (c, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_property (Property prop) {
            if (abort_tree)
                return;
            if (callback (prop, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_method (Method m) {
            if (abort_tree)
                return;
            if (callback (m, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
        public override void visit_local_variable (LocalVariable local) {
            if (abort_tree)
                return;
            if (callback (local, 0) == IterCallbackReturns.ABORT_TREE)
                abort_tree = true;
        }
    }

    /*
     * Generic callback for iteration functions.
     */
    public delegate IterCallbackReturns iter_callback (Symbol symbol, int depth);
    public enum IterCallbackReturns {
        CONTINUE,
        ABORT_BRANCH,
        ABORT_TREE
    }

    /*
     * Iterate through a symbol and its children.
     */
    public static bool iter_symbol (Symbol smb,
                                    iter_callback callback,
                                    int depth = 0) {

        if (smb.name != null)  //TODO: This is a part of a nasty workaround to ignore old symbols left after re-parsing.
            if (smb.name == "")
                return true;

        var ret = callback (smb, depth);
        if (ret == IterCallbackReturns.ABORT_BRANCH)
            return true;
        else if (ret == IterCallbackReturns.ABORT_TREE)
            return false;

        if (smb is Namespace) {
            var cv = (Namespace) smb;
            var nam = cv.get_namespaces();
            foreach (Symbol s in nam)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var enm = cv.get_enums();
            foreach (Symbol s in enm)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var err = cv.get_error_domains();
            foreach (Symbol s in err)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var str = cv.get_structs();
            foreach (Symbol s in str)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var inf = cv.get_interfaces();
            foreach (Interface s in inf)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cls = cv.get_classes();
            foreach (Symbol s in cls)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var fld = cv.get_fields();
            foreach (Symbol s in fld)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var del = cv.get_delegates();
            foreach (Symbol s in del)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is Class) {
            var cv = (Class) smb;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var enm = cv.get_enums();
            foreach (Symbol s in enm)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var str = cv.get_structs();
            foreach (Symbol s in str)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cls = cv.get_classes();
            foreach (Symbol s in cls)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var fld = cv.get_fields();
            foreach (Symbol s in fld)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var del = cv.get_delegates();
            foreach (Symbol s in del)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is Enum) {
            var cv = (Enum) smb;
            var val = cv.get_values();
            foreach (Symbol s in val)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is ErrorDomain) {
            var cv = (ErrorDomain) smb;
            var erc = cv.get_codes();
            foreach (Symbol s in erc)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is Interface) {
            var cv = (Interface) smb;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var enm = cv.get_enums();
            foreach (Symbol s in enm)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var str = cv.get_structs();
            foreach (Symbol s in str)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cls = cv.get_classes();
            foreach (Symbol s in cls)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var fld = cv.get_fields();
            foreach (Symbol s in fld)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var del = cv.get_delegates();
            foreach (Symbol s in del)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is Struct) {
            var cv = (Struct) smb;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var prp = cv.get_properties();
            foreach (Symbol s in prp)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var fld = cv.get_fields();
            foreach (Symbol s in fld)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is ObjectTypeSymbol) {
            var cv = (ObjectTypeSymbol) smb;
            var prp = cv.get_properties();
            foreach (Symbol s in prp)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var sgn = cv.get_signals();
            foreach (Symbol s in sgn)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        return true;
    }


    public delegate IterCallbackReturns iter_statement_callback (Statement statement,
                                                                 int depth);

    /*
     * Iterate through a subroutine's body's statements.
     */
    public static void iter_subroutine (Subroutine subroutine, iter_statement_callback callback) {
        var statements = subroutine.body.get_statements();
        foreach (Statement st in statements)
            iter_statement (st, callback, 0);
    }

    /*
     * Iterate through a statement.
     */
    public static bool iter_statement (Statement statement,
                                       iter_statement_callback callback,
                                       int depth = 0,
                                       string typename = "") {
        var ret = callback (statement, depth);
        if (ret == IterCallbackReturns.ABORT_BRANCH)
            return true;
        else if (ret == IterCallbackReturns.ABORT_TREE)
            return false;

        if (statement is Loop) {
            var st = (Loop) statement;
            if (!iter_statement (st.body, callback, depth + 1, "loop"))
                return false;
        }
        if (statement is DoStatement) {
            var st = (DoStatement) statement;
            if (!iter_statement (st.body, callback, depth + 1, "do_statement"))
                return false;
        }
        if (statement is ForStatement) {
            var st = (ForStatement) statement;
            if (!iter_statement (st.body, callback, depth + 1, "for_statement"))
                return false;
        }
        if (statement is ForeachStatement) {
            var st = (ForeachStatement) statement;
            if (!iter_statement (st.body, callback, depth + 1, "foreach_statement"))
                return false;
        }
        if (statement is DoStatement) {
            var st = (DoStatement) statement;
            if (!iter_statement (st.body, callback, depth + 1, "do_statement"))
                return false;
        }
        if (statement is WhileStatement) {
            var st = (WhileStatement) statement;
            if (!iter_statement (st.body, callback, depth + 1, "while_statement"))
                return false;
        }
        if (statement is SwitchStatement) {
            var st = (SwitchStatement) statement;
            foreach (SwitchSection section in st.get_sections())
                if (!iter_statement (section, callback, depth + 1, "switch_statement"))
                    return false;
        }
        if (statement is IfStatement) {
            var st = (IfStatement) statement;
            if (!iter_statement (st.true_statement, callback, depth + 1, "if_true_statement"))
                return false;
            if (st.false_statement != null)
                if (!iter_statement (st.false_statement, callback, depth + 1, "if_false_statement"))
                    return false;
        }
        if (statement is LockStatement) {
            var st = (LockStatement) statement;
            if (st.body != null)
                if (!iter_statement (st.body, callback, depth + 1, "lock_statement"))
                    return false;
        }
        if (statement is TryStatement) {
            var st = (TryStatement) statement;
            if (st.body != null)
                if (!iter_statement (st.body, callback, depth + 1, "try_statement"))
                    return false;
            if (st.finally_body != null)
                if (!iter_statement (st.finally_body, callback, depth + 1, "try_statement"))
                    return false;
            foreach (CatchClause cl in st.get_catch_clauses ())
                if (!iter_statement (cl.body, callback, depth + 1, "try_statement"))
                    return false;
        }
        if (statement is Block) {
            var st = (Block) statement;
            foreach (Statement ch in st.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "block"))
                    return false;
        }

        return true;
    }

    public delegate IterCallbackReturns iter_expression_callback (Expression expression,
                                                                 int depth);

    public static bool iter_expressions (Statement statement,
                                       iter_expression_callback callback,
                                       int depth = 0) {
        if (statement is SwitchSection) {
            var st = (SwitchSection) statement;
            foreach (SwitchLabel lbl in st.get_labels())
                return iter_expressions_int (lbl.expression, callback, depth + 1);
        }
        if (statement is Vala.ExpressionStatement) {
            var cv = statement as Vala.ExpressionStatement;
            return iter_expressions_int (cv.expression, callback, depth + 1);
        }
        if (statement is Vala.DeleteStatement) {
            var cv = statement as Vala.DeleteStatement;
            return iter_expressions_int (cv.expression, callback, depth + 1);
        }
        if (statement is Vala.SwitchStatement) {
            var cv = statement as Vala.SwitchStatement;
            return iter_expressions_int (cv.expression, callback, depth + 1);
        }
        if (statement is Vala.WhileStatement) {
            var cv = statement as Vala.WhileStatement;
            return iter_expressions_int (cv.condition, callback, depth + 1);
        }
        if (statement is Vala.ThrowStatement) {
            var cv = statement as Vala.ThrowStatement;
            return iter_expressions_int (cv.error_expression, callback, depth + 1);
        }
        if (statement is Vala.DoStatement) {
            var cv = statement as Vala.DoStatement;
            return iter_expressions_int (cv.condition, callback, depth + 1);
        }
        if (statement is Vala.IfStatement) {
            var cv = statement as Vala.IfStatement;
            return iter_expressions_int (cv.condition, callback, depth + 1);
        }
        if (statement is Vala.LockStatement) {
            var cv = statement as Vala.LockStatement;
            return iter_expressions_int (cv.resource, callback, depth + 1);
        }
        if (statement is Vala.UnlockStatement) {
            var cv = statement as Vala.UnlockStatement;
            return iter_expressions_int (cv.resource, callback, depth + 1);
        }
        if (statement is Vala.YieldStatement) {
            var cv = statement as Vala.YieldStatement;
            if (cv.yield_expression != null)
                return iter_expressions_int (cv.yield_expression, callback, depth + 1);
        }
        if (statement is Vala.ForStatement) {
            var cv = statement as Vala.ForStatement;
            foreach (Expression expr in cv.get_initializer())
                return iter_expressions_int (expr, callback, depth + 1);
            foreach (Expression expr in cv.get_iterator())
                return iter_expressions_int (expr, callback, depth + 1);
            if (cv.condition != null)
                return iter_expressions_int (cv.condition, callback, depth + 1);
        }
        if (statement is Vala.ForeachStatement) {
            var cv = statement as Vala.ForeachStatement;
            return iter_expressions_int (cv.collection, callback, depth + 1);
        }
        if (statement is Vala.ReturnStatement) {
            var cv = statement as Vala.ReturnStatement;
            if (cv.return_expression != null)
                return iter_expressions_int (cv.return_expression, callback, depth + 1);
        }
        return true;
    }
    private static bool iter_expressions_int (Expression expression,
                                       iter_expression_callback callback,
                                       int depth) {
        var ret = callback (expression, depth);
        if (ret == IterCallbackReturns.ABORT_BRANCH)
            return true;
        else if (ret == IterCallbackReturns.ABORT_TREE)
            return false;

        // TODO: InitializerList?
        if (expression is Assignment) {
            var cv = expression as Assignment;
            if (!iter_expressions_int (cv.left, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.right, callback, depth + 1))
                return false;
        }
        if (expression is BinaryExpression) {
            var cv = expression as BinaryExpression;
            if (!iter_expressions_int (cv.left, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.right, callback, depth + 1))
                return false;
        }
        if (expression is MemberAccess) {
            var cv = expression as MemberAccess;
            if (cv.inner != null)
                if (!iter_expressions_int (cv.inner, callback, depth + 1))
                    return false;
        }
        if (expression is AddressofExpression) {
            var cv = expression as AddressofExpression;
            if (cv.inner != null)
                if (!iter_expressions_int (cv.inner, callback, depth + 1))
                    return false;
        }
        if (expression is CastExpression) {
            var cv = expression as AddressofExpression;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is ConditionalExpression) {
            var cv = expression as ConditionalExpression;
            if (!iter_expressions_int (cv.condition, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.true_expression, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.false_expression, callback, depth + 1))
                return false;
        }
        if (expression is ElementAccess) {
            var cv = expression as ElementAccess;
            if (!iter_expressions_int (cv.container, callback, depth + 1))
                return false;
        }
        if (expression is LambdaExpression) {
            var cv = expression as LambdaExpression;
            if (!iter_expressions (cv.statement_body, callback, depth + 1))
                return false;
        }
        if (expression is MethodCall) {
            var cv = expression as MethodCall;
            if (!iter_expressions_int (cv.call, callback, depth + 1))
                return false;
            foreach (Expression e in cv.get_argument_list())
                if (!iter_expressions_int (e, callback, depth + 1))
                    return false;
        }
        if (expression is NamedArgument) {
            var cv = expression as NamedArgument;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is ObjectCreationExpression) {
            var cv = expression as ObjectCreationExpression;
            foreach (Expression e in cv.get_argument_list())
                if (!iter_expressions_int (e, callback, depth + 1))
                    return false;
        }
        if (expression is PointerIndirection) {
            var cv = expression as PointerIndirection;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is PostfixExpression) {
            var cv = expression as PostfixExpression;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is ReferenceTransferExpression) {
            var cv = expression as ReferenceTransferExpression;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is UnaryExpression) {
            var cv = expression as UnaryExpression;
            if (!iter_expressions_int (cv.inner, callback, depth + 1))
                return false;
        }
        if (expression is SliceExpression) {
            var cv = expression as SliceExpression;
            if (!iter_expressions_int (cv.container, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.start, callback, depth + 1))
                return false;
            if (!iter_expressions_int (cv.stop, callback, depth + 1))
                return false;
        }
        if (expression is Template) {
            var cv = expression as Template;
            foreach (Expression e in cv.get_expressions())
                if (!iter_expressions_int (e, callback, depth + 1))
                    return false;
        }
        if (expression is Tuple) {
            var cv = expression as Tuple;
            foreach (Expression e in cv.get_expressions())
                if (!iter_expressions_int (e, callback, depth + 1))
                    return false;
        }
        if (expression is TypeCheck) {
            var cv = expression as TypeCheck;
            if (!iter_expressions_int (cv.expression, callback, depth + 1))
                return false;
        }
        return true;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
