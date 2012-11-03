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

        void build_syntax_map(){

            var file = File.new_for_path ("/usr/share/valama/syntax");

            var dis = new DataInputStream (file.read ());
            string line;
            while ((line = dis.read_line (null)) != null) {
                if (line.strip() == "" || line.has_prefix("#"))
                    continue;

                string[] rule_line_split = dis.read_line (null).split(" ");
                RuleExpression[] rule_exprs = new RuleExpression[rule_line_split.length];
                for(int q = 0; q < rule_line_split.length; q++){
                    rule_exprs[q] = new RuleExpression();
                    rule_exprs[q].expr = rule_line_split[q];
                }

                string[] namesplit = line.split_set(" :,");

                string[] parameters = new string[0];
                foreach (string splt in namesplit[1 : namesplit.length])
                    if (splt != "")
                        parameters += splt;


                map_syntax[namesplit[0]] = new SyntaxRule(parameters, rule_exprs);
            }

        }
        class SyntaxRule{
            public SyntaxRule (string[] parameters, RuleExpression[] rule){
                this.parameters = parameters;
                this.rule = rule;
            }
            public string[] parameters;
            public RuleExpression[] rule;
        }
        Gee.HashMap<string, SyntaxRule> map_syntax = new Gee.HashMap<string, SyntaxRule>();

        public Gee.HashSet<Symbol>? propose_symbols(SourceFile file, int line, int col, string written){
            var accessible = get_accessible_symbols(file, line, col);
            var inside_symbol = get_symbol_at_pos(file, line, col);

            //return begin_inside_function(inside_symbol, accessible, written);

            rule_id_count = 0;
            return compare(map_syntax["init_method"].rule, accessible, written, new Gee.ArrayList<CallParameter>(), 0);

        }

        string str_until(string str){
            //return str.substring(0, str.index_of(until));
            int index = str.index_of(" ");
            if (index == -1)
                return str;
            return str.substring(0, index);
        }

        bool symbol_is_type(Symbol smb, string type){
            if (type == "Parameter" && smb is Vala.Parameter)
                return true;
            if (type == "Variable" && smb is Variable)
                return true;
            if (type == "Method" && smb is Method)
                return true;
            if (type == "Class" && smb is Class)
                return true;
            if (type == "Namespace" && smb is Namespace)
                return true;
            return false;
        }

        class CallParameter{
            public int for_rule_id;
            public string name;
            public Symbol symbol;
        }

        class RuleExpression{
            public string expr;
            public int rule_id;
            public RuleExpression clone(){
                var ret = new RuleExpression();
                ret.expr = this.expr;
                ret.rule_id = this.rule_id;
                return ret;
            }
        }

        CallParameter find_param(Gee.ArrayList<CallParameter> array, string name, int rule_id){
            foreach (CallParameter param in array)
                if (param.name == name && param.for_rule_id == rule_id)
                    return param;
            return null;
        }

int rule_id_count = 0;

        Gee.HashSet<Symbol>? compare (RuleExpression[] compare_rule, Symbol[] accessible, string written2, Gee.ArrayList<CallParameter> call_params, int depth){//

            string written = written2; //For some reason need to create a copy... otherwise assigning new values to written doesn't work

            Gee.HashSet<Symbol> ret = new Gee.HashSet<Symbol>();
            
            RuleExpression[] rule = new RuleExpression[compare_rule.length];
            for (int q = 0; q < rule.length; q++)
                rule[q] = compare_rule[q].clone();
            RuleExpression current_rule = rule[0];

string depth_string = "";
for (int q = 0; q < depth; q++)
    depth_string += " ";
stdout.printf("\n" + depth_string + "Current rule: " + current_rule.expr + "\n");
stdout.printf(depth_string + "Written: " + written + "\n");

            if (current_rule.expr.contains("|")){
                var splt = current_rule.expr.split("|");
                foreach (string s in splt){
                    rule[0].expr = s;
                    ret.add_all(compare(rule, accessible, written, call_params, depth + 1));
                }
                return ret;
            }

            if (current_rule.expr.has_prefix("?")){
                var r1 = compare(rule[1:rule.length], accessible, written, call_params, depth + 1);
                rule[0].expr = rule[0].expr.substring(1);
                var r2 = compare(rule, accessible, written, call_params, depth + 1);
                ret.add_all(r1);
                ret.add_all(r2);
                return ret;
            }

            string write_to_param = null;
            if (current_rule.expr.has_suffix("}")){
                int bracket_start = current_rule.expr.last_index_of("{");

                write_to_param = current_rule.expr.substring(bracket_start + 1, current_rule.expr.length - bracket_start - 2);
                current_rule.expr = current_rule.expr.substring(0, bracket_start);
            }

            if (current_rule.expr == "_"){
                if (!(written.has_prefix(" ") || written.has_prefix("\t")))
                    return new Gee.HashSet<Symbol>();
                written = written.chug();
                return compare (rule[1:rule.length], accessible, written, call_params, depth + 1);
            }
            if (current_rule.expr.has_prefix("{")){
                int bracket_end = current_rule.expr.index_of("}>");
                Symbol parent = find_param(call_params, current_rule.expr.substring(1, bracket_end - 1), current_rule.rule_id).symbol;
                current_rule.expr = current_rule.expr.substring(bracket_end + 2);

                var children = get_child_symbols(get_type_of_symbol(parent));
                foreach (Symbol child in children){
                    if (symbol_is_type(child, current_rule.expr)){
                        if (written.has_prefix(child.name)){
                            var child_param = new CallParameter();
                            child_param.for_rule_id = current_rule.rule_id;
                            child_param.name = write_to_param;
                            child_param.symbol = child;
                            call_params.add(child_param);
                            written = written.substring(child.name.length);
                            return compare (rule[1:rule.length], accessible, written, call_params, depth + 1);
                        }
                        if (child.name.has_prefix(written))
                            ret.add(child);
                    }
                }
                return ret;
            }
            if (current_rule.expr.has_prefix("%")){
                string filter_type = current_rule.expr.substring(1);
                foreach (Symbol smb in accessible)
                    if (symbol_is_type(smb, filter_type)){
                        var eq = match(written, smb.name);
                        if (eq == matchres.STARTED)
                            ret.add(smb);
                        if (eq == matchres.COMPLETE){
                            if (write_to_param != null){
                                var child_param = new CallParameter();
                                child_param.for_rule_id = current_rule.rule_id;
                                child_param.name = write_to_param;
                                child_param.symbol = smb;
                                call_params.add(child_param);
                            }
                            written = written.substring(smb.name.length);
                            return compare(rule[1:rule.length], accessible, written, call_params, depth + 1);
                        }
                    }
                return ret;
            }
            if (current_rule.expr.has_prefix("$")){
                string call = current_rule.expr.substring(1);
                RuleExpression[] composit_rule = map_syntax[call].rule;
                rule_id_count ++;
                foreach (RuleExpression subexp in composit_rule)
                    subexp.rule_id = rule_id_count;

                foreach (RuleExpression exp in rule[1:rule.length])
                    composit_rule += exp;

                if (write_to_param != null){
                    var child_param = new CallParameter();
                    child_param.for_rule_id = rule_id_count;
                    child_param.name = map_syntax[call].parameters[0];
                    child_param.symbol = find_param(call_params, write_to_param, current_rule.rule_id).symbol;// call_params[write_to_param];
                    call_params.add(child_param);

                }

                return compare(composit_rule, accessible, written, call_params, depth + 1);

                /*Regex r = /^\s*(?P<parameter>.*)\s*=\s*(?P<value>.*)\s*$/;
                MatchInfo info;
                if(r.match(the_string, 0, out info)) {
                    var parameter = info.fetch_named("parameter");
                    var value = info.fetch_named("value");
                }*/
            }

            var mres = match (written, current_rule.expr);

            if (mres == matchres.COMPLETE){
                written = written.substring(current_rule.expr.length);
                if (rule.length == 1)
                    return ret;
                return compare(rule[1 : rule.length], accessible, written, call_params, depth + 1);
            }
            else if (mres == matchres.STARTED){
                ret.add(new Struct(current_rule.expr, null, null));
                return ret;
            }
            return ret;
        }

        enum matchres{
            UNEQUAL,
            STARTED,
            COMPLETE
        }
        matchres match(string written, string target){
            if (written.length >= target.length)
                if (written.has_prefix(target))
                    return matchres.COMPLETE;
            if (target.length > written.length && target.has_prefix(written))
                return matchres.STARTED;
            return matchres.UNEQUAL;
        }

        Symbol? get_type_of_symbol(Symbol smb){
            Symbol type = null;
            if (smb is Class || smb is Namespace || smb is Struct || smb is Enum)
                type = smb;
            if (smb is Property)
                type = ((Property)smb).property_type.data_type;
            if (smb is Variable)
                type = ((Variable)smb).variable_type.data_type;
            if (smb is Method)
                type = ((Method)smb).return_type.data_type;
            return type;
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
                var vapi_path = context.get_vapi_path(package_name);
                if (vapi_path == null)
                    continue;

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


}

// vim: set ai ts=4 sts=4 et sw=4
