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

namespace Guanako {

    public class CompletionProposal{
        public CompletionProposal(Symbol smb, int rep_length){
            this.symbol = smb;
            this.replace_length = rep_length;
        }
        public Symbol symbol;
        public int replace_length;
    }


     public class project {

        CodeContext context;
        /*
         * Not a beautiful piece of code, but necessary to convert from
         * Vala.List.
         */
        public SourceFile[] get_source_files() {
            SourceFile[] files = new SourceFile[0];
            foreach (SourceFile file in context.get_source_files())
                if (file.file_type == SourceFileType.SOURCE)
                    files += file;
            return files;
        }

        Vala.Parser parser;
        public Gee.ArrayList<string> packages = new Gee.ArrayList<string>();

        public project(){
            context = new CodeContext();
            parser = new Vala.Parser();

            context.profile = Profile.GOBJECT;

            universal_parameter = new CallParameter();
            universal_parameter.name = "@";
            universal_parameter.symbol = null;

            build_syntax_map();
        }

        public void remove_file (SourceFile file) {
            var old_files = context.get_source_files();
            var old_packages = context.get_packages();
            context = new CodeContext();
            parser = new Vala.Parser();
            foreach (SourceFile old_file in old_files)
                if (old_file != file)
                    context.add_source_file (old_file);
            foreach (string pkg in old_packages)
                context.add_package (pkg);
            update();
        }

        public Symbol root_symbol {
            get { return context.root; }
        }

        public CodeContext code_context {
            get { return context; }
        }

        public void add_packages (string[] package_names, bool auto_update) {
            var deps = get_package_dependencies (packages.to_array());

            var new_deps = package_names;
            foreach (string pkg in get_package_dependencies (package_names))
                if (!(pkg in deps))
                    new_deps += pkg;

            foreach (string package_name in package_names) {
                packages.add (package_name);
                context.add_external_package (package_name);
            }

            if (auto_update)
                foreach (string pkg in new_deps) {
                    var pkg_file = get_source_file (context.get_vapi_path (pkg));
                    if (pkg_file == null)
                        continue;
                    update_file (pkg_file);
                }
        }

        SourceFile? get_source_file (string filename) {
            foreach (SourceFile file in context.get_source_files())
                if (file.filename == filename)
                    return file;
            return null;
        }

        public void remove_package (string package_name) {
            packages.remove (package_name);
            var deps = get_package_dependencies (packages.to_array());

            var unused = new string[]{package_name};
            foreach (string pkg in get_package_dependencies (new string[] {package_name}))
                if (!(pkg in deps))
                    unused += pkg;

            foreach (string pkg in unused) {
                packages.remove (pkg);
                var pkg_file = get_source_file (context.get_vapi_path (pkg));
                if (pkg_file == null)
                    continue;
                vanish_file (pkg_file);
            }
        }

        public void add_source_file (SourceFile source_file) {
            context.add_source_file (source_file);
        }

        public void update() {
            CodeContext.push (context);
            parser.parse (context);

            //TODO: Find missing packages automatically
            /*var namespaces = new string[0];
            foreach (SourceFile file in context.get_source_files())
                foreach (UsingDirective dir in file.current_using_directives)
                        if (!(dir.namespace_symbol.name in namespaces))
                            namespaces += dir.namespace_symbol.name;
            foreach (var namesp in namespaces) {
                var vapi = discover_vapi_file (namesp);
                add_package (vapi);
                stdout.printf ("Adding package '" +
                               vapi +
                               "' for namespace '" +
                               namesp + "'\n");
            }*/
            context.resolver.resolve (context);
            context.analyzer.analyze (context);
            CodeContext.pop();
        }

        void build_syntax_map() {
            var file = File.new_for_path ("/usr/share/valama/syntax");

            try {
                var dis = new DataInputStream (file.read());
                string line;
                while ((line = dis.read_line (null)) != null) {
                    if (line.strip() == "" || line.has_prefix ("#"))
                        continue;

                    string[] rule_line_split = dis.read_line (null).split (" ");
                    RuleExpression[] rule_exprs = new RuleExpression[rule_line_split.length];
                    for(int q = 0; q < rule_line_split.length; q++) {
                        rule_exprs[q] = new RuleExpression();
                        rule_exprs[q].expr = rule_line_split[q];
                    }

                    string[] namesplit = line.split_set (" :,");

                    string[] parameters = new string[0];
                    foreach (string splt in namesplit[1:namesplit.length])
                        if (splt != "")
                            parameters += splt;

                    map_syntax[namesplit[0]] = new SyntaxRule (parameters, rule_exprs);
                }
            } catch (IOError e) {
                stderr.printf ("Could not read syntax file: %s", e.message);
                Gtk.main_quit();
                // return 1;
            } catch (Error e) {
                stderr.printf ("An error occured: %s", e.message);
                Gtk.main_quit();
                // return 1;
            }

        }

        class SyntaxRule {
            public SyntaxRule (string[] parameters, RuleExpression[] rule) {
                this.parameters = parameters;
                this.rule = rule;
            }
            public string[] parameters;
            public RuleExpression[] rule;
        }
        Gee.HashMap<string, SyntaxRule> map_syntax = new Gee.HashMap<string, SyntaxRule>();

        public Gee.HashSet<CompletionProposal>? propose_symbols (SourceFile file,
                                                     int line,
                                                     int col,
                                                     string written) {
            var accessible = get_accessible_symbols (file, line, col);
            var inside_symbol = get_symbol_at_pos (file, line, col);

            rule_id_count = 0;
            if (inside_symbol == null)
                return compare (map_syntax["init_deep_space"].rule,
                                get_child_symbols(context.root),
                                written, new Gee.ArrayList<CallParameter>(),
                                0);
            else
                return compare (map_syntax["init_method"].rule,
                                accessible,
                                written, new Gee.ArrayList<CallParameter>(),
                                0);

        }

        bool symbol_is_type (Symbol smb, string type) {
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
            if (type == "Enum" && smb is Enum)
                return true;
            if (type == "Constant" && smb is Constant)
                return true;
            if (type == "Property" && smb is Property)
                return true;
            if (type == "Signal" && smb is Vala.Signal)
                return true;
            if (type == "Struct" && smb is Struct)
                return true;
            return false;
        }

        bool symbol_has_binding(Symbol smb, string binding){
            if (smb is Method){
                if (binding == "<static>" && ((Method)smb).binding == MemberBinding.STATIC)
                    return true;
                else if (binding == "<instance>" && ((Method)smb).binding == MemberBinding.INSTANCE)
                    return true;
            } else if (smb is Field){
                if (binding == "<static>" && ((Field)smb).binding == MemberBinding.STATIC)
                    return true;
                else if (binding == "<instance>" && ((Field)smb).binding == MemberBinding.INSTANCE)
                    return true;
            } else if (smb is Property){
                if (binding == "<static>" && ((Property)smb).binding == MemberBinding.STATIC)
                    return true;
                else if (binding == "<instance>" && ((Property)smb).binding == MemberBinding.INSTANCE)
                    return true;
            } else if (smb is Variable){
                if (binding == "<instance>")
                    return true;
            }
            return false;
        }

        class CallParameter {
            public int for_rule_id;
            public string name;
            public Symbol? symbol;
        }
        CallParameter universal_parameter;

        class RuleExpression {
            public string expr;
            public int rule_id;
            public RuleExpression clone() {
                var ret = new RuleExpression();
                ret.expr = this.expr;
                ret.rule_id = this.rule_id;
                return ret;
            }
        }

        CallParameter? find_param (Gee.ArrayList<CallParameter> array,
                                   string name,
                                   int rule_id) {
            if (name == "@")
                return universal_parameter;
            foreach (CallParameter param in array)
                if (param.name == name && param.for_rule_id == rule_id)
                    return param;
            return null;
        }

        int rule_id_count = 0;

        Gee.HashSet<CompletionProposal>? compare (RuleExpression[] compare_rule,
                                      Symbol[] accessible,
                                      string written2,
                                      Gee.ArrayList<CallParameter> call_params,
                                      int depth) {

            /*
             * For some reason need to create a copy... otherwise assigning new
             * values to written doesn't work
             */
            string written = written2;

            Gee.HashSet<CompletionProposal> ret = new Gee.HashSet<CompletionProposal>();

            RuleExpression[] rule = new RuleExpression[compare_rule.length];
            for (int q = 0; q < rule.length; q++)
                rule[q] = compare_rule[q].clone();
            RuleExpression current_rule = rule[0];

            //Uncomment this to see every step the parser takes in a tree structure
            /*string depth_string = "";
            for (int q = 0; q < depth; q++)
                depth_string += " ";
            stdout.printf ("\n" + depth_string + "Current rule: " + current_rule.expr + "\n");
            stdout.printf (depth_string + "Written: " + written + "\n");*/

            if (current_rule.expr.contains ("|")) {
                var splt = current_rule.expr.split ("|");
                foreach (string s in splt) {
                    rule[0].expr = s;
                    ret.add_all (compare (rule, accessible, written, call_params, depth + 1));
                }
                return ret;
            }

            if (current_rule.expr.has_prefix ("?")) {
                if (rule.length > 1)
                    ret.add_all (compare (rule[1:rule.length], accessible, written, call_params, depth + 1));
                rule[0].expr = rule[0].expr.substring (1);
                var r2 = compare (rule, accessible, written, call_params, depth + 1);
                ret.add_all (r2);
                return ret;
            }

            string write_to_param = null;
            if (current_rule.expr.has_suffix ("}")) {
                int bracket_start = current_rule.expr.last_index_of ("{");

                write_to_param = current_rule.expr.substring (bracket_start + 1, current_rule.expr.length - bracket_start - 2);
                current_rule.expr = current_rule.expr.substring (0, bracket_start);
            }

            if (current_rule.expr.has_prefix ("*word")) {
                Regex r = /^(?P<word>\w*)(?P<rest>.*)$/;
                MatchInfo info;
                if (!r.match (written, 0, out info))
                    return ret;
                if (info.fetch_named ("word") == "")
                    return ret;
                return compare (rule[1:rule.length], accessible, info.fetch_named ("rest"), call_params, depth + 1);
            }


            if (current_rule.expr == "_") {
                if (!(written.has_prefix (" ") || written.has_prefix ("\t")))
                    return ret;
                written = written.chug();
                return compare (rule[1:rule.length], accessible, written, call_params, depth + 1);
            }

            if (current_rule.expr.has_prefix ("{")) {
                Regex r = /^{(?P<parent>.*)}>(?P<child>\w*)(?P<binding>.*)$/;
                MatchInfo info;
                if (!r.match (current_rule.expr, 0, out info)) {
                    stdout.printf ("Malformed rule! >" + compare_rule[0].expr + "<\n");
                    return ret;
                }

                var parent_param_name = info.fetch_named ("parent");
                var child_type = info.fetch_named ("child");
                var binding = info.fetch_named ("binding");

                var parent_param = find_param (call_params, parent_param_name, current_rule.rule_id);
                if (parent_param == null){
                    stdout.printf (@"Variable $parent_param_name not found! >$(compare_rule[0].expr)<\n");
                    return ret;
                }
                Symbol[] children;
                if (parent_param.symbol == null)
                    children = accessible;
                else
                    children = get_child_symbols (get_type_of_symbol (parent_param.symbol));

                Regex r2 = /^(?P<word>\w*)(?P<rest>.*)$/;
                MatchInfo info2;
                if(!r2.match (written, 0, out info2))
                    return ret;
                var word = info2.fetch_named ("word");
                var rest = info2.fetch_named ("rest");

                foreach (Symbol child in children){
                    if (symbol_is_type (child, child_type)){
                        if (binding != "")
                            if (!symbol_has_binding(child, binding))
                                continue;
                        if (word == child.name){
                            var child_param = new CallParameter();
                            child_param.for_rule_id = current_rule.rule_id;
                            child_param.name = write_to_param;
                            child_param.symbol = child;
                            call_params.add (child_param);
                            ret.add_all (compare (rule[1:rule.length], accessible, rest, call_params, depth + 1));
                        }
                        if (rest == "" && child.name.has_prefix (word) && child.name.length > word.length)
                            ret.add (new CompletionProposal(child, word.length));
                    }
                }
                return ret;
            }
            if (current_rule.expr.has_prefix ("$")) {
                string call = current_rule.expr.substring (1);
                if (!map_syntax.has_key (call)) {
                    stdout.printf (@"Call $call not found in >$(compare_rule[0].expr)<\n");
                    return ret;
                }

                RuleExpression[] composit_rule = map_syntax[call].rule;
                rule_id_count ++;
                foreach (RuleExpression subexp in composit_rule)
                    subexp.rule_id = rule_id_count;

                foreach (RuleExpression exp in rule[1:rule.length])
                    composit_rule += exp;

                if (write_to_param != null) {
                    var child_param = new CallParameter();
                    child_param.name = map_syntax[call].parameters[0];
                    child_param.for_rule_id = rule_id_count;
                    var param = find_param (call_params, write_to_param, current_rule.rule_id);  // call_params[write_to_param];
                    if (param == null) {
                        stdout.printf (@"Parameter $write_to_param not found in >$(compare_rule[0].expr)<\n");
                        return ret;
                    }
                    child_param.symbol = param.symbol;

                    call_params.add (child_param);

                }

                return compare (composit_rule, accessible, written, call_params, depth + 1);

            }

            var mres = match (written, current_rule.expr);

            if (mres == matchres.COMPLETE) {
                written = written.substring (current_rule.expr.length);
                if (rule.length == 1)
                    return ret;
                return compare (rule[1:rule.length], accessible, written, call_params, depth + 1);
            }
            else if (mres == matchres.STARTED) {
                ret.add (new CompletionProposal(new Struct(current_rule.expr, null, null), written.length));
                return ret;
            }
            return ret;
        }

        enum matchres {
            UNEQUAL,
            STARTED,
            COMPLETE
        }

        matchres match (string written, string target) {
            if (written.length >= target.length)
                if (written.has_prefix (target))
                    return matchres.COMPLETE;
            if (target.length > written.length && target.has_prefix (written))
                return matchres.STARTED;
            return matchres.UNEQUAL;
        }

        Symbol? get_type_of_symbol (Symbol smb){
            Symbol type = null;
            if (smb is Class || smb is Namespace || smb is Struct || smb is Enum)
                type = smb;
            if (smb is Property)
                type = ((Property) smb).property_type.data_type;
            if (smb is Variable)
                type = ((Variable) smb).variable_type.data_type;
            if (smb is Method)
                type = ((Method) smb).return_type.data_type;
            return type;
        }

        public Symbol[] get_accessible_symbols (SourceFile file, int line, int col) {
            Symbol [] ret = new Symbol[0];
            var current_symbol = get_symbol_at_pos (file, line, col);

            if (current_symbol == null) {
                return ret;
            }

            foreach (UsingDirective directive in file.current_using_directives) {
                var children = get_child_symbols (directive.namespace_symbol);
                foreach (Symbol s in children)
                    ret += s;
            }

            for (Scope scope = current_symbol.scope; scope != null; scope = scope.parent_scope)
                foreach (Symbol s in scope.get_symbol_table().get_values())
                    ret += s;

            /*
             * If we are inside a subroutine, propose all previously defined
             * local variables.
             */
            if (current_symbol is Subroutine) {
                var sr = (Subroutine) current_symbol;

                Statement[] candidates = new Statement[0];
                int[] depths = new int[0];

                int last_depth = -1;
                /* Add all statements before selected one to candidates. */

                iter_subroutine(sr, (statement, depth) => {
                    if (inside_source_ref (file, line, col, statement.source_reference)) {
                        if (depth > last_depth)
                            last_depth = depth;
                        return iter_callback_returns.abort_tree;
                    }
                    if (before_source_ref (file, line, col, statement.source_reference)) {
                        if (depth > last_depth)
                            last_depth = depth;
                        return iter_callback_returns.abort_tree;
                    }
                    if (statement is DeclarationStatement || statement is ForeachStatement) {
                        candidates += statement;
                        depths += depth;
                    }
                    return iter_callback_returns.continue;
                });

                /*
                 * Return all candidates with a lower or equal depth.
                 */
                for (int q = candidates.length - 1; q >= 0; q--) {
                    if (depths[q] <= last_depth || last_depth == -1) {
                        /*if (candidates[q] is ForStatement) {
                            var expressions = ((ForStatement) candidates[q]).get_initializer();
                            foreach (Expression expr in expressions) {
                                stdout.printf(expr.symbol_reference.name + "!!\n");
                            }
                            //if (fst.type_reference != null)
                            //    ret += new Variable (fst.type_reference, fst.variable_name);
                        }*/
                        if (candidates[q] is ForeachStatement && depths[q] + 1 <= last_depth) {  //depth + 1, as iterator variable is only available inside the loop
                            var fst = (ForeachStatement) candidates[q];
                            if (fst.type_reference != null)
                                ret += new Variable (fst.type_reference, fst.variable_name);
                        }
                        if (candidates[q] is DeclarationStatement) {
                            var dsc = (DeclarationStatement) candidates[q];
                            if (dsc.declaration != null)
                                ret += dsc.declaration;
                        }
                        last_depth = depths[q];
                    }
                }

            }

            return ret;
        }

        public Symbol? get_symbol_at_pos (SourceFile source_file, int line, int col) {
            Symbol ret = null;
            int last_depth = -1;
            iter_symbol (context.root, (smb, depth) => {
                if (smb.name != null) {
                    SourceReference sref = smb.source_reference;
                    if (sref == null)
                        return iter_callback_returns.continue;

                    /*
                     * Check symbol's own source reference.
                     */
                    if (inside_source_ref(source_file, line, col, sref)){
                        if (depth > last_depth){  //Get symbol deepest in the tree
                            ret = smb;
                            last_depth = depth;
                        }
                    }

                    /*
                     * If the symbol is a subroutine, check its body's source
                     * reference.
                     */
                    if (smb is Subroutine) {
                        var sr = (Subroutine) smb;
                        if (sr.body != null)
                            if (inside_source_ref (source_file, line, col, sr.body.source_reference))
                                if (depth > last_depth) {  //Get symbol deepest in the tree
                                    ret = smb;
                                    last_depth = depth;
                                }
                    }
                }
                return iter_callback_returns.continue;
            }, 0);
            return ret;
        }

        public string[] get_package_dependencies (string[] package_names) {
            string[] ret = new string[0];
            foreach (string package_name in package_names) {
                var vapi_path = context.get_vapi_path (package_name);
                if (vapi_path == null)
                    continue;

                string deps_filename = vapi_path.substring (0, vapi_path.length - 5) + ".deps";

                var deps_file = File.new_for_path (deps_filename);
                if (deps_file.query_exists()) {
                    try {
                        var dis = new DataInputStream (deps_file.read());
                        string line;
                        while ((line = dis.read_line (null)) != null) {
                            if (!(line in ret))
                                ret += line;
                        }
                    } catch (IOError e) {
                        stderr.printf ("Could not read line: %s", e.message);
                    } catch (Error e) {
                        stderr.printf ("Could not read file: %s", e.message);
                    }
                }
            }
            if (ret.length > 0) {
                var child_dep = get_package_dependencies (ret);
                foreach (string dep in child_dep)
                    ret += dep;
            }
            return ret;
        }

        void vanish_file (SourceFile file) {
            var nodes = new Vala.ArrayList<Vala.CodeNode>();
            foreach (var node in file.get_nodes()) {
                nodes.add (node);
            }
            foreach (var node in nodes) {
                file.remove_node (node);
                if (node is Vala.Symbol) {
                    var sym = (Vala.Symbol) node;
                    if (sym.owner != null)
                        /*
                         * We need to remove it from the scope.
                         */
                        sym.owner.remove(sym.name);
                    if (context.entry_point == sym)
                        context.entry_point = null;
                    sym.name = "";  //TODO: Find a less stupid solution...
                }
            }
        }

        public void update_file (Vala.SourceFile file, string? new_content = null) {
            if (new_content != null)
                file.content = new_content;
            lock (context) {
                /*
                 * Removing nodes in the same loop causes problems (probably
                 * due to ReadOnlyList).
                 */

                Vala.CodeContext.push (context);

                vanish_file (file);

                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                file.add_using_directive (ns_ref);
                context.root.add_using_directive (ns_ref);

                parser.visit_source_file (file);

                context.resolver.resolve (context);
                context.analyzer.visit_source_file (file);
                context.check();

                Vala.CodeContext.pop();
            }
        }

     }
}

// vim: set ai ts=4 sts=4 et sw=4
