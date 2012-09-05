/**
 * src/guanako.vala
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
using Gee;

namespace Guanako{

     public class project {

        CodeContext context;
        Vala.Parser parser;

        public project(){
            context = new CodeContext ();
            parser = new Vala.Parser();

            context.profile = Profile.GOBJECT;

            build_syntax_map();
        }
        public Symbol root_symbol {
            get { return context.root; }
        }
        public CodeContext code_context{
            get { return context; }
        }
        public void add_package(string package_name){
            context.add_external_package (package_name);
        }
        public void add_source_file(SourceFile source_file){
            context.add_source_file (source_file);
        }
        public void update(){
            CodeContext.push(context);
            parser.parse(context);

            //TODO: Find missing packages automatically
            /*var namespaces = new string[0];
            foreach (SourceFile file in context.get_source_files())
                foreach (UsingDirective dir in file.current_using_directives)
                        if (!(dir.namespace_symbol.name in namespaces))
                            namespaces += dir.namespace_symbol.name;
            foreach (var namesp in namespaces){
                var vapi = discover_vapi_file(namesp);
                add_package(vapi);
                stdout.printf("Adding package '" + vapi + "' for namespace '" + namesp + "'\n");
            }*/
            context.resolver.resolve(context);
            context.analyzer.analyze(context);
            CodeContext.pop();
        }
        int index_of_symbol_end(string written){
            int first_index = written.index_of(" ");
            if (written.index_of(",") != -1 && written.index_of(",") < first_index)
                first_index = written.index_of(",");
            if (written.index_of(")") != -1 && written.index_of(")") < first_index)
                first_index = written.index_of(")");
            if (written.index_of("(") != -1 && written.index_of("(") < first_index)
                first_index = written.index_of("(");
            if (first_index == -1)
                first_index = written.length;
            return first_index;
        }

        bool type_offered(Symbol smb, string type){
            if (type == "namespace")
                if (smb is Namespace)
                    return true;
            if (type == "type")
                if (smb is Namespace || smb is Class || smb is Struct)
                    return true;
            if (type == "object")
                if (smb is Namespace || smb is Class || smb is Struct || smb is Variable || smb is Method || smb is Property)
                    return true;
            if (type == "creation")
                if (smb is Namespace || smb is Class || smb is Method)
                    return true;
           if (type == "method")
                if (smb is Namespace || smb is Class || smb is Method){
                    /*if (smb is Method){
                        var mth = smb as Method;
                        if (mth.return_type.data_type is Class)
                            return true;
                        else
                            return false;
                    }*/
                    return true;
                }
           return false;
        }
        bool type_required(Symbol smb, string type){
            stdout.printf("required check type: " + type + " Symbol: " + smb.name + "\n");
            if (type == "namespace")
                if (smb is Namespace)
                    return true;
            if (type == "type")
                if (smb is Class || smb is Struct)
                    return true;
            if (type == "object")
                if (smb is Variable || smb is Method || smb is Property || smb is ObjectType){
                    /*if (smb is Method){
                        var mth = smb as Method;
                        if (mth.return_type.data_type is Class)
                            return true;
                        else
                            return false;
                    }*/
                    return true;
                }
            if (type == "creation")
                if (smb is Class || smb is CreationMethod)
                    return true;
           if (type == "method"){
                stdout.printf("METHOD: " + smb.name + "\n");
                if (smb is Method)
                    return true;
                stdout.printf("NO!\n");
            }
            return false;
        }
        Symbol[]? cmp(string written, string[] compare, int step, Symbol[] accessible){
            if (compare.length == step)
                return null;

            if (compare[step].contains("|")){
                Symbol[] ret = new Symbol[0];
                foreach (string comp in compare[step].split("|")){
                    string[] compare_option = compare; //Try every option
                    compare_option[step] = comp;
                    Symbol[] r = cmp(written, compare_option, step, accessible);
                    foreach (Symbol smb in r)
                        ret += smb;
                }
                return ret;
            }

            if (compare[step] == "*")
                return cmp (written.substring(index_of_symbol_end(written)), compare, step + 1, accessible);
            if (compare[step].has_prefix("?")){
                string[] compare_absolute = compare; //Try both with and without the current comparison, then return both results
                compare_absolute[step] = compare_absolute[step].substring(1);
                Symbol[] ret = new Symbol[0];
                Symbol[]? one = cmp(written, compare_absolute, step, accessible);
                Symbol[]? two = cmp(written, compare, step + 1, accessible);
                if (one != null)
                    foreach (Symbol s in one)
                        ret += s;
                if (two != null)
                    foreach (Symbol s in two)
                        ret += s;
                return ret;
            }
            if (compare[step].has_prefix("$")){
                string[] compare_resolved = map_syntax[compare[step].substring(1)].split(" ");
                string[] new_compare = new string[0];
                if (step > 0)
                    new_compare = compare[0 : step];
                foreach (string s in compare_resolved)
                    new_compare += s;
                for (int q = step + 1; q < compare.length; q++)
                    new_compare += compare[q];
                return cmp (written, new_compare, step, accessible);
            }
            /*if (compare[step] == "#"){
                if (written.has_prefix(" "))
                    return cmp (written.chug(), compare, step + 1, accessible);
                else
                    return null;
            }*/
            if (compare[step] == "_")
                return cmp (written.chug(), compare, step + 1, accessible);
            if (compare[step] == "namespace" || compare[step] == "type" || compare[step] == "object" || compare[step] == "creation" || compare[step] == "method"){
                stdout.printf("compare step: " + compare[step] + " _ written: " + written + "\n");
                string me = written.substring(0, index_of_symbol_end(written));
                Symbol resolved = resolve_symbol(me, accessible);
                stdout.printf("resolving: " + me + "\n");
                if (resolved != null)
                    stdout.printf("FOUND!!" + resolved.name + "\n");
                if (me.length < written.length){
                    if (resolved != null && type_required(resolved, compare[step]))
                         return cmp (written.substring(me.length), compare, step + 1, accessible);
                    else
                        return null;
                } else {
                    Symbol[] ret = new Symbol[0];
                    Symbol[] check = accessible;
                    if (resolved != null)
                        check = get_child_symbols(resolved);
                   foreach (Symbol s in check){
                        if (type_offered(s, compare[step])){
                            ret += s;
                        }
                    }
                    return ret;
                }
            }
            if (written == compare[step])
                return null;
            if (compare[step].length > written.length && compare[step].has_prefix(written)){
                return new Symbol[1]{new Struct(compare[step], null, null)};
            }
            if (written.has_prefix(compare[step]))
                return cmp (written.substring(compare[step].length), compare, step + 1, accessible);
            return null;
        }

void build_syntax_map(){
    map_syntax["method_call"] = "method _ ( _ ?$parameters _ ) _ ;";
    map_syntax["if_statement"] = "if _ ( _ object _ ?$comparison _ )";

    map_syntax["parameters_decl"] = "type _ * _ ?, _ ?$parameters_decl";
    map_syntax["parameters"] = "object _ ?, _ ?$parameters";

    map_syntax["comparison"] = "== _ object";

    map_syntax["begr"] = "123 _ abcde _ ?$begr";
    map_syntax["abegr"] = "(  _ $begr _ )";
}

Gee.HashMap<string, string> map_syntax = new Gee.HashMap<string, string>();

string[] syntax_deep_space  = new string[]{
    "using _ namespace _ ;",
    "namespace _ * _",
    "class _ * _"
};
string[] syntax_class  = new string[]{
    "class _ * _",
    "public _ type _ * _",
    "type _ * _"
};
string[] syntax_function  = new string[]{
    "foreach _ ( _ type _ in _ object _ )",
    "for _ ( _ type _  * _ = _ object _ ; _ object _ * _ object _ ; _ object _ * _  ) _ ;",

    "var _ * _ = _ new _ creation _ ( _ ?$parameters _ ) _  ;",
    "var _ * _ = _ object _ ;",
    "var _ * _ = _ object _ ;",
    "object _ = _ new _ creation _ ( _ ?$parameters _ ) _  ;",

    "$method_call",
    "$if_statement",

    "Hallo|Hai _ ?$abegr _ Tag",

    "if _ ( _ object _ * _ object _ )"
};

        public Symbol[] propose_symbols(SourceFile file, int line, int col, string written){
            Symbol[] ret = null;
            var accessible = get_accessible_symbols(file, line, col);
            var inside_symbol = get_symbol_at_pos(file, line, col);
            string[] syntax = null;
            if (inside_symbol == null){
                syntax = syntax_deep_space;
                accessible = get_child_symbols(context.root);
            }else if (inside_symbol is Subroutine)
                syntax = syntax_function;
            else if (inside_symbol is Class)
                syntax = syntax_class;
            else
                return ret;

            foreach (string snt in syntax){
                var res = cmp(written.chug() , snt.split(" "), 0, accessible);
                if (res != null)
                    foreach (Symbol s in res)
                        ret += s;
            }
            return ret;
         }

        Symbol? resolve_symbol(string text, Symbol[]? candidates = null){
            Symbol[] internal_candidates = candidates;

            var txt = text;

            int depth = 0;
            int start_id = 0;
            bool found = false;
            do {
                found = false;
                for (int q = 0; q < txt.length; q++){
                    if (txt[q].to_string() == "("){
                        if (depth < 1)
                            start_id = q;
                        depth ++;
                    } else if (txt[q].to_string() == ")"){
                        depth --;
                        if (depth == 0){
                            txt = txt.substring(0, start_id) + txt.substring(q + 1);
                            found = true;
                        }
                    }
                }
            } while (found);

            int last_occurrence = int.max(-1, txt.last_index_of("("));
            last_occurrence = int.max(last_occurrence, txt.last_index_of(","));
            if (last_occurrence >= 0)
                txt = txt.substring(last_occurrence + 1);

            string[] splt = txt.split(".");
            //if (splt.length == 1)
            //    return null;

            if (candidates == null){
                internal_candidates = get_child_symbols(context.root);
            }


             foreach (Symbol smb in internal_candidates){
                 if (smb.name == splt[0]){

                    if (splt.length == 1)
                        return smb;

                    Symbol type = null;
                    if (smb is Class || smb is Namespace || smb is Struct)
                        type = smb;
                    if (smb is Property)
                        type = ((Property)smb).property_type.data_type;
                    if (smb is Variable)
                        type = ((Variable)smb).variable_type.data_type;
                    if (smb is Method)
                        type = ((Method)smb).return_type.data_type;
                    if (type == null)
                        continue;

                    if (splt.length == 2){
                        var rt = resolve_symbol(txt.substring(splt[0].length + 1), get_child_symbols(type));
                        stdout.printf("RES: " + txt.substring(splt[0].length + 1) + "\n");
                        stdout.printf("SYM: " + rt.name + "\n");
                        if (rt != null)
                            return rt;
                        return type;
                    }else
                        return resolve_symbol(txt.substring(splt[0].length + 1), get_child_symbols(type));
                 }
             }
             return null;
         }

         public Symbol[] get_accessible_symbols(SourceFile file, int line, int col){
            Symbol [] ret = new Symbol[0];
            var current_symbol = get_symbol_at_pos(file, line, col);
            if (current_symbol == null){
                return ret;
            }

            for (Scope scope = current_symbol.scope; scope != null; scope = scope.parent_scope)
                foreach (Symbol s in scope.get_symbol_table().get_values())
                    ret += s;

            foreach (UsingDirective directive in file.current_using_directives){
                var children = get_child_symbols(directive.namespace_symbol);
                foreach (Symbol s in children)
                    ret += s;
            }

            //If we are inside a subroutine, propose all previously defined local variables
            if (current_symbol is Subroutine){
                var sr = (Subroutine)current_symbol;

                Statement[] candidates = new Statement[0];
                int[] depths = new int[0];

                int last_depth = -1;
                //Add all statements before selected one to candidates

                iter_subroutine(sr, (statement, depth)=>{
                    if (inside_source_ref(file, line, col, statement.source_reference)){
                        if (depth > last_depth)
                            last_depth = depth;
                        return iter_callback_returns.abort_tree;
                    }
                    if (before_source_ref(file, line, col, statement.source_reference)){
                        if (depth > last_depth)
                            last_depth = depth;
                        return iter_callback_returns.abort_tree;
                    }
                    if (statement is DeclarationStatement || statement is ForeachStatement){
                        candidates += statement;
                        depths += depth;
                    }
                    return iter_callback_returns.continue;
                });

                //Return all candidates with a lower or equal depth
                for (int q = candidates.length - 1; q >= 0; q--){
                    if (depths[q] <= last_depth || last_depth == -1){
                        /*if (candidates[q] is ForStatement){
                            var expressions = ((ForStatement)candidates[q]).get_initializer();
                            foreach (Expression expr in expressions){
                                stdout.printf(expr.symbol_reference.name + "!!\n");
                            }
                            //if (fst.type_reference != null)
                            //    ret += new Variable(fst.type_reference, fst.variable_name);
                        }*/
                        if (candidates[q] is ForeachStatement && depths[q] + 1 <= last_depth){//depth + 1, as iterator variable is only available inside the loop
                            var fst = (ForeachStatement)candidates[q];
                            if (fst.type_reference != null)
                                ret += new Variable(fst.type_reference, fst.variable_name);
                        }
                        if (candidates[q] is DeclarationStatement){
                            var dsc = (DeclarationStatement)candidates[q];
                            if (dsc.declaration != null)
                                ret += dsc.declaration;
                        }
                        last_depth = depths[q];
                    }
                }

            }

            return ret;
        }

        public Symbol? get_symbol_at_pos(SourceFile source_file, int line, int col){
            Symbol ret = null;
            int last_depth = -1;
            iter_symbol (context.root, (smb, depth)=>{
                if (smb.name != null){
                    SourceReference sref = smb.source_reference;
                    if (sref == null)
                        return iter_callback_returns.continue;

                    //Check symbol's own source reference
                    if (inside_source_ref(source_file, line, col, sref)){
                        if (depth > last_depth){//Get symbol deepest in the tree
                            ret = smb;
                            last_depth = depth;
                        }
                    }
                    //If the symbol is a subroutine, check its body's source reference
                    if (smb is Subroutine){
                        var sr = (Subroutine)smb;
                        if (sr.body != null)
                            if (inside_source_ref(source_file, line, col, sr.body.source_reference))
                                if (depth > last_depth){//Get symbol deepest in the tree
                                    ret = smb;
                                    last_depth = depth;
                                }
                    }
                }
                return iter_callback_returns.continue;
            }, 0);
            return ret;
        }


        public void update_file (Vala.SourceFile file, string new_content) {
            file.content = new_content;
            lock (context) {
                /* Removing nodes in the same loop causes problems (probably due to ReadOnlyList)*/

                Vala.CodeContext.push (context);

                var nodes = new Vala.ArrayList<Vala.CodeNode> ();
                foreach (var node in file.get_nodes()) {
                    nodes.add(node);
                }
                foreach (var node in nodes) {
                    file.remove_node (node);
                    if (node is Vala.Symbol) {
                        var sym = (Vala.Symbol) node;
                        if (sym.owner != null)
                            // we need to remove it from the scope
                            sym.owner.remove(sym.name);
                        if (context.entry_point == sym)
                            context.entry_point = null;
                        sym.name = ""; //TODO: Find a less stupid solution...
                    }
                }
                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                file.add_using_directive (ns_ref);
                context.root.add_using_directive (ns_ref);

                //report.clear_error_indicators ();


                /* visit_source_file checks for the file extension */
                parser.visit_source_file (file);

                context.resolver.resolve (context);
                context.analyzer.visit_source_file (file);
                context.check();

                Vala.CodeContext.pop ();

                //report.update_errors(current_editor);
            }
        }

     }




     //Helper function for checking whether a given source location is inside a SourceReference
    public static bool before_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.first_line > source_line)
            return true;
        if (reference.first_line == source_line && reference.first_column > source_col)
            return true;
        return false;
    }
    public static bool after_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.last_line < source_line)
            return true;
        if (reference.last_line == source_line && reference.last_column < source_col)
            return true;
        return false;
    }
    public static bool inside_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.first_line > source_line || reference.last_line < source_line)
            return false;
        if (reference.first_line == source_line && reference.first_column > source_col)
            return false;
        if (reference.last_line == source_line && reference.last_column < source_col)
            return false;
        return true;
    }


}

// vim: set ai ts=4 sts=4 et sw=4
