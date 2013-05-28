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
    Symbol[] get_child_symbols (Symbol parent) {
        Symbol[] ret = new Symbol[0];
        if (parent is Class) {
            //If parent is a Class, add its base class and types (i.e. interfaces it implements etc)
            var p = (Class) parent;
            if (p.base_class != null)
                ret = get_child_symbols (p.base_class);
            foreach (DataType type in p.get_base_types()) {
                iter_symbol (type.data_type, (s) => {
                    ret += s;
                    return IterCallbackReturns.ABORT_BRANCH;
                });
            }
        }

        iter_symbol (parent, (s) => {
            ret += s;
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
        if (depth > 0) {
            if (smb.name != null)  //TODO: This is a part of a nasty workaround to ignore old symbols left after re-parsing.
                if (smb.name == "")
                    return true;

            var ret = callback (smb, depth);
            if (ret == IterCallbackReturns.ABORT_BRANCH)
                return true;
            else if (ret == IterCallbackReturns.ABORT_TREE)
                return false;
        }

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

        if (statement is Block) {
            var st = (Block) statement;
            foreach (Statement ch in st.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "block"))
                    return false;
        }
        if (statement is Loop) {
            var st = (Loop) statement;
            foreach (Statement ch in st.body.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "loop"))
                    return false;
        }
        if (statement is ForStatement) {
            var st = (ForStatement) statement;
            foreach (Statement ch in st.body.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "for_statement"))
                    return false;
        }
        if (statement is ForeachStatement) {
            var st = (ForeachStatement) statement;
            foreach (Statement ch in st.body.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "foreach_statement"))
                    return false;
        }
        if (statement is DoStatement) {
            var st = (DoStatement) statement;
            foreach (Statement ch in st.body.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "do_statement"))
                    return false;
        }
        if (statement is WhileStatement) {
            var st = (WhileStatement) statement;
            foreach (Statement ch in st.body.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "while_statement"))
                    return false;
        }
        if (statement is IfStatement) {
            var st = (IfStatement) statement;
            foreach (Statement ch in st.true_statement.get_statements())
                if (!iter_statement (ch, callback, depth + 1, "if_true_statement"))
                    return false;
            if (st.false_statement != null)
                foreach (Statement ch in st.false_statement.get_statements())
                    if (!iter_statement (ch, callback, depth + 1, "if_false_statement"))
                        return false;
        }
        if (statement is LockStatement) {
            var st = (LockStatement) statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements())
                    if (!iter_statement (ch, callback, depth + 1, "lock_statement"))
                        return false;
        }
        if (statement is TryStatement) {
            var st = (TryStatement) statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements())
                    if (!iter_statement (ch, callback, depth + 1, "try_statement"))
                        return false;
        }

        return true;
    }

}

// vim: set ai ts=4 sts=4 et sw=4
