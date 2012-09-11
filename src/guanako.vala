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
        public Gee.ArrayList<string> packages = new Gee.ArrayList<string>();

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
        public void add_packages(string[] package_names){
            var deps = get_package_dependencies(packages.to_array());

            var new_deps = package_names;
            foreach (string pkg in get_package_dependencies(package_names))
                if (!(pkg in deps))
                    new_deps += pkg;

            foreach (string package_name in package_names){
                packages.add(package_name);
                context.add_external_package (package_name);
            }

            foreach (string pkg in new_deps){
                var pkg_file = get_source_file(context.get_vapi_path(pkg));
                if (pkg_file == null)
                    continue;
                update_file(pkg_file);
            }
        }
        SourceFile? get_source_file(string filename){
            foreach (SourceFile file in context.get_source_files())
                if (file.filename == filename)
                    return file;
            return null;
        }
        public void remove_package(string package_name){

            packages.remove(package_name);
            var deps = get_package_dependencies(packages.to_array());

            var unused = new string[]{package_name};
            foreach (string pkg in get_package_dependencies(new string[]{package_name}))
                if (!(pkg in deps))
                    unused += pkg;

            foreach (string pkg in unused){
                packages.remove(pkg);
                var pkg_file = get_source_file(context.get_vapi_path(pkg));
                if (pkg_file == null)
                    continue;
                vanish_file(pkg_file);
            }
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
            if (type == "raw_namespace")
                if (smb is Namespace)
                    return true;
            if (type == "raw_type")
                if (smb is Namespace || smb is Class || smb is Struct || smb is Interface)
                    return true;
            if (type == "raw_object")
                if (smb is Namespace || smb is Class || smb is Struct || smb is Variable || smb is Method || smb is Property || smb is Constant)
                    return true;
            if (type == "raw_creation")
                if (smb is Namespace || smb is Class || smb is Method)
                    return true;
           if (type == "raw_method")
                if (smb is Namespace || smb is Class || smb is Interface || smb is Method){
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
            if (type == "raw_namespace")
                if (smb is Namespace)
                    return true;
            if (type == "raw_type")
                if (smb is Class || smb is Struct || smb is Interface)
                    return true;
            if (type == "raw_object")
                if (smb is Variable || smb is Method || smb is Property || smb is ObjectType || smb is Constant){
                    /*if (smb is Method){
                        var mth = smb as Method;
                        if (mth.return_type.data_type is Class)
                            return true;
                        else
                            return false;
                    }*/
                    return true;
                }
            if (type == "raw_creation")
                if (smb is Class || smb is CreationMethod)
                    return true;
           if (type == "raw_method"){
                if (smb is Method)
                    return true;
            }
            return false;
        }
        Gee.HashSet<Symbol?> cmp(string written, string[] compare, int step, Symbol[] accessible){
            if (compare.length == step)
                return null;

            if (compare[step].contains("|")){
                var ret = new Gee.HashSet<Symbol?>();
                foreach (string comp in compare[step].split("|")){
                    string[] compare_option = compare; //Try every option
                    compare_option[step] = comp;
                    var r = cmp(written, compare_option, step, accessible);
                    foreach (Symbol smb in r)
                        ret.add(smb);
                }
                return ret;
            }

            if (compare[step] == "*")
                return cmp (written.substring(index_of_symbol_end(written)), compare, step + 1, accessible);
            if (compare[step].has_prefix("?")){
                string[] compare_absolute = compare; //Try both with and without the current comparison, then return both results
                compare_absolute[step] = compare_absolute[step].substring(1);
                var ret = new Gee.HashSet<Symbol?>();
                var one = cmp(written, compare_absolute, step, accessible);
                var two = cmp(written, compare, step + 1, accessible);
                if (one != null)
                    ret.add_all(one);
                if (two != null)
                    ret.add_all(two);
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
            if (compare[step] == "_")
                return cmp (written.chug(), compare, step + 1, accessible);
            if (compare[step] == "raw_namespace" || compare[step] == "raw_type" || compare[step] == "raw_object" || compare[step] == "raw_creation" || compare[step] == "raw_method"){
                string me = written.substring(0, index_of_symbol_end(written));
                Symbol resolved = resolve_symbol(me, accessible);
                if (me.length < written.length){
                    if (resolved != null && type_required(resolved, compare[step]))
                         return cmp (written.substring(me.length), compare, step + 1, accessible);
                    else
                        return null;
                } else {
                    var ret = new Gee.HashSet<Symbol?>();
                    Symbol[] check = accessible;
                    if (resolved != null)
                        check = get_child_symbols(get_type_of_symbol(resolved));
                   string[] splt = me.split(".");
                   string last_name = "";
                   if (splt.length > 0)
                       last_name = splt[splt.length - 1];
                   foreach (Symbol s in check){
                        if (type_offered(s, compare[step])){
                            if (s.name.has_prefix(last_name))
                                ret.add(s);
                        }
                    }
                    return ret;
                }
            }
            if (written == compare[step])
                return null;
            if (compare[step].length > written.length && compare[step].has_prefix(written)){
                var ret = new Gee.HashSet<Symbol?>();
                ret.add(new Struct(compare[step], null, null));
                return ret;
            }
            if (written.has_prefix(compare[step]))
                return cmp (written.substring(compare[step].length), compare, step + 1, accessible);
            return null;

        }

void build_syntax_map(){

    var file = File.new_for_path ("/usr/share/valama/syntax");

    var dis = new DataInputStream (file.read ());
    string line;
    while ((line = dis.read_line (null)) != null) {
        if (line.strip() == "" || line.has_prefix("#"))
            continue;
        map_syntax[line] = dis.read_line (null);
    }

}

Gee.HashMap<string, string> map_syntax = new Gee.HashMap<string, string>();

string[] syntax_deep_space  = new string[]{
    "using _ raw_namespace _ ;",
    "namespace _ * _",
    "?$access_keyword _ class _ * _"
};
string[] syntax_class  = new string[]{
    "?$access_keyword _ class _ * _",
    "?$access_keyword _ raw_type _ * _",
    "?$access_keyword _ raw_type _ * _ ( _ $parameters_decl _ )"
};
string[] syntax_function  = new string[]{
    "$foreach_statement",
    "$for_statement",
    "$local_declaration",

    "$assignment",

    "$method_call",
    "$if_statement"
};

        public Gee.HashSet<Symbol?> propose_symbols(SourceFile file, int line, int col, string written){
            var ret = new Gee.HashSet<Symbol?>();
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
                    ret.add_all(res);
            }
            return ret;
         }

        Symbol? get_type_of_symbol(Symbol smb){
            Symbol type = null;
            if (smb is Class || smb is Namespace || smb is Struct)
                type = smb;
            if (smb is Property)
                type = ((Property)smb).property_type.data_type;
            if (smb is Variable)
                type = ((Variable)smb).variable_type.data_type;
            if (smb is Method)
                type = ((Method)smb).return_type.data_type;
            return type;
        }

        Symbol? resolve_symbol(string text, Symbol[] candidates){
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

            string[] splt1 = txt.split_set("(,");
            if (splt1.length > 0)
                txt = splt1[splt1.length - 1];

            string[] splt = txt.split(".");

             foreach (Symbol smb in internal_candidates){
                 if (smb.name == splt[0]){

                    var type = get_type_of_symbol(smb);

                    if (splt.length == 1)
                        return smb;

                    if (type == null)
                        continue;

                    if (splt.length == 2){
                        var rt = resolve_symbol(txt.substring(splt[0].length + 1), get_child_symbols(type));
                        if (rt != null)
                            return rt;
                        return smb;
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

        public string[] get_package_dependencies(string[] package_names){
            string[] ret = new string[0];
            foreach (string package_name in package_names){
                string vapi_path = context.get_vapi_path(package_name);

                string deps_filename = vapi_path.substring(0, vapi_path.length - 5) + ".deps";

                var deps_file = File.new_for_path(deps_filename);
                if (deps_file.query_exists()){
                    var dis = new DataInputStream (deps_file.read ());
                    string line;
                    while ((line = dis.read_line (null)) != null) {
                        if (!(line in ret))
                            ret += line;
                    }
                }
            }
            if (ret.length > 0){
                var child_dep = get_package_dependencies(ret);
                foreach (string dep in child_dep)
                    ret += dep;
            }
            return ret;
        }


        void vanish_file(SourceFile file){
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
        }

        public void update_file (Vala.SourceFile file, string? new_content = null) {
            if (new_content != null)
                file.content = new_content;
            lock (context) {
                /* Removing nodes in the same loop causes problems (probably due to ReadOnlyList)*/

                Vala.CodeContext.push (context);

                vanish_file(file);

                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                file.add_using_directive (ns_ref);
                context.root.add_using_directive (ns_ref);

                parser.visit_source_file (file);

                context.resolver.resolve (context);
                context.analyzer.visit_source_file (file);
                context.check();

                Vala.CodeContext.pop ();
            }
        }

     }




     //Helper function for checking whether a given source location is inside a SourceReference
    public static bool before_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.@sourceref_begin@line > source_line)
            return true;
        if (reference.@sourceref_begin@line == source_line && reference.@sourceref_begin@column > source_col)
            return true;
        return false;
    }
    public static bool after_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.@sourceref_end@line < source_line)
            return true;
        if (reference.@sourceref_end@line == source_line && reference.@sourceref_end@column < source_col)
            return true;
        return false;
    }
    public static bool inside_source_ref(SourceFile source_file, int source_line, int source_col, SourceReference? reference){
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.@sourceref_begin@line > source_line || reference.@sourceref_end@line < source_line)
            return false;
        if (reference.@sourceref_begin@line == source_line && reference.@sourceref_begin@column > source_col)
            return false;
        if (reference.@sourceref_end@line == source_line && reference.@sourceref_end@column < source_col)
            return false;
        return true;
    }


}

// vim: set ai ts=4 sts=4 et sw=4
