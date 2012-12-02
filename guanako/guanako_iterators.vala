/*
 * guanako/guanako_iterators.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
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

    /*
     * Get parent's children.
     */
    Symbol[] get_child_symbols (Symbol parent) {
        Symbol[] ret = new Symbol[0];
        //if (include_base_classes)
            if (parent is Class) {
                var p = (Class) parent;
                if (p.base_class != null)
                    ret = get_child_symbols (p.base_class);
            }

        iter_symbol(parent, (s, depth) => {
            ret += s;
            return iter_callback_returns.abort_branch;
        });
        return ret;
    }

    /*
     * Find smb's namespace.
     */
    public Namespace? get_parent_namespace (Symbol smb) {
        for (var iter = smb; iter != null; iter = iter.parent_symbol) {
            if (iter is Namespace)
                    return (Namespace) iter;
        }
        return null;
    }

    /*
     * Generic callback for iteration functions.
     */
    public delegate iter_callback_returns iter_callback (Symbol symbol, int depth);
    public enum iter_callback_returns {
        continue = 1,
        abort_branch,
        abort_tree
    }

    /*
     * Iterate through a symbol and its children.
     */
    public static bool iter_symbol (Symbol smb, iter_callback callback, int depth = 0) {
        if (depth > 0){
            if (smb.name != null)  //TODO: This is a part of a nasty workaround to ignore old symbols left after re-parsing.
                if (smb.name == "")
                    return true;

            var ret = callback (smb, depth);
            if (ret == iter_callback_returns.abort_branch)
                return true;
            else if (ret == iter_callback_returns.abort_tree)
                return false;
        }

        if (smb is Namespace) {
            var cv = (Namespace) smb;
            var ch = cv.get_namespaces();
            foreach (Symbol s in ch)
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cls = cv.get_classes();
            foreach (Symbol s in cls)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var inf = cv.get_interfaces();
            foreach (Interface s in inf)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var cst = cv.get_constants();
            foreach (Symbol s in cst)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var fld = cv.get_fields();
            foreach (Symbol s in fld)
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
        }
        if (smb is Class) {
            var cv = (Class) smb;
            var cls = cv.get_classes();
            foreach (Symbol s in cls) {
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var cst = cv.get_constants();
            foreach (Symbol s in cst) {
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var fld = cv.get_fields();
            foreach (Symbol s in fld){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var enm = cv.get_enums();
            foreach (Symbol s in enm)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var str = cv.get_structs();
            foreach (Symbol s in str)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is Struct) {
            var cv = (Struct) smb;
            var mth = cv.get_methods();
            foreach (Symbol s in mth){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var cst = cv.get_constants();
            foreach (Symbol s in cst){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var fld = cv.get_fields();
            foreach (Symbol s in fld){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
            var prp = cv.get_properties();
            foreach (Symbol s in prp){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
        }
        if (smb is Enum){
            var enm = (Enum)smb;
            foreach (Symbol s in enm.get_values())
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
        }
        if (smb is ObjectTypeSymbol) {
            var cv = (ObjectTypeSymbol) smb;
            var mth = cv.get_methods();
            foreach (Symbol s in mth)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var sgn = cv.get_signals();
            foreach (Symbol s in sgn)
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            var prp = cv.get_properties();
            foreach (Symbol s in prp){
                if (!iter_symbol (s, callback, depth + 1))
                    return false;
            }
        }
        return true;
    }


    public delegate iter_callback_returns iter_statement_callback (Statement statement, int depth);

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
    public static bool iter_statement (Statement statement, iter_statement_callback callback, int depth) {
        var ret = callback (statement, depth);
        if (ret == iter_callback_returns.abort_branch)
            return true;
        else if (ret == iter_callback_returns.abort_tree)
            return false;

        if (statement is Block) {
            var st = (Block) statement;
            foreach (Statement ch in st.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is Loop) {
            var st = (Loop) statement;
            foreach (Statement ch in st.body.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is ForStatement) {
            var st = (ForStatement) statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is ForeachStatement) {
            var st = (ForeachStatement) statement;
            foreach (Statement ch in st.body.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is DoStatement) {
            var st = (DoStatement) statement;
            foreach (Statement ch in st.body.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is WhileStatement) {
            var st = (WhileStatement) statement;
            foreach (Statement ch in st.body.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is IfStatement) {
            var st = (IfStatement) statement;
            foreach (Statement ch in st.true_statement.get_statements()) {
                if (!iter_statement (ch, callback, depth + 1))
                    return false;
            }
            if (st.false_statement != null)
                foreach (Statement ch in st.false_statement.get_statements()) {
                    if (!iter_statement (ch, callback, depth + 1))
                        return false;
                }
        }
        if (statement is LockStatement) {
            var st = (LockStatement) statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements()) {
                    if (!iter_statement (ch, callback, depth + 1))
                        return false;
                }
        }
        if (statement is TryStatement) {
            var st = (TryStatement) statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements()) {
                    if (!iter_statement (ch, callback, depth + 1))
                        return false;
                }
        }

        return true;
    }

}

// vim: set ai ts=4 sts=4 et sw=4
