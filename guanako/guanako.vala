/*
 * guanako/guanako.vala
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
    public class CompletionProposal {
        public CompletionProposal (Symbol smb, int rep_length) {
            this.symbol = smb;
            this.replace_length = rep_length;
        }
        public Symbol symbol;
        public int replace_length;
    }


    public class project {
        CodeContext context;
        Vala.Parser parser;
        int glib_major = 2;  //TODO: Make this an option.
        int glib_minor = 32;

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

        public bool add_source_file (SourceFile source_file) {
            foreach (SourceFile file in get_source_files())
                if (file.filename == source_file.filename)
                    return false;
            context.add_source_file (source_file);
            return true;
        }

        public SourceFile? add_source_file_by_name (string filename) {
            var source_file = new SourceFile (context,
                                              SourceFileType.SOURCE,
                                              filename);
            if (!add_source_file (source_file))
                return null;
            return source_file;
        }

        public void set_report_wrapper(Report report_wrapper){
            context.report = report_wrapper;
        }

        public Gee.ArrayList<string> packages = new Gee.ArrayList<string>();

        public project(){
            context = new CodeContext();
            parser = new Vala.Parser();

            context_prep();

            universal_parameter = new CallParameter();
            universal_parameter.name = "@";

            build_syntax_map();
        }

        /**
         * Set {@link Vala.CodeContext} options and flags.
         */
        private void context_prep() {
            context.target_glib_major = glib_major;
            context.target_glib_minor = glib_minor;
            for (int i = 16; i <= glib_minor; i += 2) {
			    context.add_define ("GLIB_%d_%d".printf (glib_major, i));
		    }
            context.profile = Profile.GOBJECT;
        }

        public void remove_file (SourceFile file) {
            var old_files = context.get_source_files();
            var old_packages = context.get_packages();
            var old_report = context.report;
            context = new CodeContext();
            context.report = old_report;
            context_prep();

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

        public void add_packages (string[] package_names, bool auto_update) {
            var deps = get_package_dependencies (packages.to_array());

            var new_deps = package_names;
            foreach (string pkg in get_package_dependencies (package_names))
                if (!(pkg in deps) && !(pkg in new_deps)) {
                    var vapi_path = context.get_vapi_path (pkg);
                    if (vapi_path == null) {
                        stderr.printf(_("Warning: Vapi for package %s not found.\n"), pkg);
                        continue;
                    }
#if DEBUG
                    stdout.printf(_("Vapi found: %s\n"), vapi_path);
#endif
                    new_deps += pkg;
                }

            foreach (string package_name in package_names) {
                /* Add .vapi even if not found. */
                //FIXME: Send signal to let apps show a warning.
                packages.add (package_name);
                var vapi_path = context.get_vapi_path (package_name);
                if (vapi_path == null) {
                    stderr.printf(_("Warning: Vapi for package %s not found.\n"), package_name);
                    continue;
                }
#if DEBUG
                stdout.printf(_("Vapi found: %s\n"), vapi_path);
#endif
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
#if DEBUG
                stdout.printf (_("Adding package '%s' for namespace '%s'\n"), vapi, namesp);
#endif
            }*/
            context.resolver.resolve (context);
            context.analyzer.analyze (context);
            CodeContext.pop();
        }

        void build_syntax_map() {
            var file = File.new_for_path (Config.PACKAGE_DATA_DIR + "/syntax");

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
                stderr.printf (_("Could not read syntax file: %s"), e.message);
                Gtk.main_quit();
                // return 1;
            } catch (Error e) {
                stderr.printf (_("An error occured: %s"), e.message);
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

        public Gee.TreeSet<CompletionProposal>? propose_symbols (SourceFile file,
                                                                 int line,
                                                                 int col,
                                                                 string written) {
            var accessible = get_accessible_symbols (file, line, col);
            var inside_symbol = get_symbol_at_pos (file, line, col);


            // TreeSet with custom sorting function
            Gee.TreeSet<CompletionProposal> ret = new Gee.TreeSet<CompletionProposal>((a,b)=>{
                var name_a = ((CompletionProposal)a).symbol.name;
                var name_b = ((CompletionProposal)b).symbol.name;
                var name_a_case = name_a.casefold();
                var name_b_case = name_b.casefold();
                if (name_a_case < name_b_case)
                    return -1;
                if (name_a_case > name_b_case)
                    return 1;
                if (name_a < name_b)
                    return -1;
                if (name_a > name_b)
                    return 1;

                return 0;
            });


            rule_id_count = 0;
            if (inside_symbol == null)
                compare (map_syntax["init_deep_space"].rule,
                                get_child_symbols (context.root),
                                written, new Gee.ArrayList<CallParameter>(),
                                0, ref ret);
            else
                compare (map_syntax["init_method"].rule,
                                accessible,
                                written, new Gee.ArrayList<CallParameter>(),
                                0, ref ret);
            return ret;
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

        bool symbol_has_binding(Symbol smb, string? binding){
            if (binding == null)
                return true;

            bool stat = binding.contains("static");
            bool inst = binding.contains("instance");
            bool arr = binding.contains("array") || binding.contains("arr_el");
            bool sng = binding.contains("single");

            if (smb is Method){
                if (inst && ((Method)smb).binding == MemberBinding.STATIC)
                    return false;
                else if (stat && ((Method)smb).binding == MemberBinding.INSTANCE)
                    return false;
            } else if (smb is Field){
                if (inst && ((Field)smb).binding == MemberBinding.STATIC)
                    return false;
                else if (stat && ((Field)smb).binding == MemberBinding.INSTANCE)
                    return false;
            } else if (smb is Property){
                if (inst && ((Property)smb).binding == MemberBinding.STATIC)
                    return false;
                else if (stat && ((Property)smb).binding == MemberBinding.INSTANCE)
                    return false;
            }
            DataType type = null;
            if (smb is Property)
                type = ((Property) smb).property_type;
            if (smb is Variable)
                type = ((Variable) smb).variable_type;
            if (smb is Method)
                type = ((Method) smb).return_type;
            if (type != null){
                if (!type.is_array() && arr)
                    return false;
                if (type.is_array() && sng)
                    return false;
            }
            return true;
        }

        class CallParameter {
            public int for_rule_id;
            public string name;

            /*public Symbol? symbol { get {return _symbol;}
                set {
                    _symbol = value;
                    if (return_to_param != null)
                        return_to_param.symbol = value;
                }
            }*/
            public void set_symbol(Symbol smb){
                _symbols = new Symbol[0];
                _symbols += smb;
                if (return_to_param != null)
                    return_to_param.add_symbol(smb);
            }
            public void add_symbols(Symbol[] smbs){
                foreach (Symbol s in smbs)
                    _symbols += s;
                if (return_to_param != null)
                    return_to_param.add_symbols(smbs);
            }
            public void add_symbol(Symbol smb){
                _symbols += smb;
                if (return_to_param != null)
                    return_to_param.add_symbol(smb);
            }
            private Symbol[] _symbols = new Symbol[0];
            public Symbol[] symbols {get{return _symbols;}}

            public CallParameter? return_to_param = null;
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
        Gee.ArrayList<CallParameter> clone_param_list (Gee.ArrayList<CallParameter> param){

            var ret = new Gee.ArrayList<CallParameter>();
            foreach (CallParameter p in param){
                var new_param = new CallParameter();
                new_param.for_rule_id = p.for_rule_id;
                var smblist = new Symbol[0];
                foreach (Symbol s in p.symbols)
                    smblist += s;
                new_param.add_symbols(smblist);
                new_param.name = p.name;
                new_param.return_to_param = p.return_to_param;
                ret.add(new_param);
            }
            foreach (CallParameter r in ret){
                if (r.return_to_param != null){
                    r.return_to_param = find_param(ret, r.return_to_param.name, r.return_to_param.for_rule_id);
                }
            }
            return ret;
        }

        int rule_id_count = 0;

        bool compare (RuleExpression[] compare_rule,
                                      Symbol[] accessible,
                                      string written2,
                                      Gee.ArrayList<CallParameter> call_params,
                                      int depth, ref Gee.TreeSet<CompletionProposal> ret) {

            /*
             * For some reason need to create a copy... otherwise assigning new
             * values to written doesn't work
             */
            string written = written2;

            RuleExpression[] rule = new RuleExpression[compare_rule.length];
            for (int q = 0; q < rule.length; q++)
                rule[q] = compare_rule[q].clone();
            RuleExpression current_rule = rule[0];

            //Uncomment this to see every step the parser takes in a tree structure
            string depth_string = "";
            for (int q = 0; q < depth; q++)
                depth_string += " ";
            stdout.printf ("\n" + depth_string + "Current rule: " + current_rule.expr + "\n");
            stdout.printf (depth_string + "Written: " + written + "\n");

            if (current_rule.expr.contains ("|")) {
                var splt = current_rule.expr.split ("|");
                bool retbool = false;
                foreach (string s in splt) {
                    rule[0].expr = s;
                    if (compare (rule, accessible, written, call_params, depth + 1, ref ret))
                        retbool = true;
                }
                return retbool;
            }

            if (current_rule.expr.has_prefix ("?")) {
                bool ret1 = false;
                if (rule.length > 1)
                    ret1 = compare (rule[1:rule.length], accessible, written, call_params, depth + 1, ref ret);
                rule[0].expr = rule[0].expr.substring (1);
                var ret2 = compare (rule, accessible, written, call_params, depth + 1, ref ret);
                return ret1 || ret2;
            }

            if (current_rule.expr.has_prefix ("*word")) {
                Regex r = /^(?P<word>\w*)(?P<rest>.*)$/;
                MatchInfo info;
                if (!r.match (written, 0, out info))
                    return false;
                if (info.fetch_named ("word") == null)
                    return false;
                return compare (rule[1:rule.length], accessible, info.fetch_named ("rest"), call_params, depth + 1, ref ret);
            }


            if (current_rule.expr == "_") {
                if (!(written.has_prefix (" ") || written.has_prefix ("\t")))
                    return false;
                written = written.chug();
                compare (rule[1:rule.length], accessible, written, call_params, depth + 1, ref ret);
                return true;
            }

            if (current_rule.expr.has_prefix ("{")) {
                Regex r = /^\{(?P<parent>.*)\}\>(?P<child>\w*)(\<(?P<binding>.*)\>)?(\{(?P<write_to>\w*)\})?$/;
                MatchInfo info;
                if (!r.match (current_rule.expr, 0, out info)) {
                    stdout.printf ("Malformed rule! >" + compare_rule[0].expr + "<\n");
                    return false;
                }

                var parent_param_name = info.fetch_named ("parent");
                var child_type = info.fetch_named ("child");
                var binding = info.fetch_named ("binding");
                var write_to_param = info.fetch_named ("write_to");

                var parent_param = find_param (call_params, parent_param_name, current_rule.rule_id);
                if (parent_param == null){
                    stdout.printf (_("Variable '%s' not found! >%s<\n"), parent_param_name, compare_rule[0].expr);
                    return false;
                }
                Symbol[] children = new Symbol[0];
                if (parent_param.symbols.length == 0)
                    children = accessible;
                else{
                    bool resolve_array = false;
                    if (binding != null)
                        resolve_array = binding.contains("arr_el");
                    foreach (Symbol parent in parent_param.symbols){
                        var tpe = get_type_of_symbol (parent, resolve_array);
                        stdout.printf(@"============ Parent: $(parent.name) Resolve array: $resolve_array Resolved: $(tpe.name) ===========\n");
                        foreach (Symbol new_child in get_child_symbols (tpe))
                            children += new_child;
                    }
                }

                Regex r2 = /^(?P<word>\w*)(?P<rest>.*)$/;
                MatchInfo info2;
                if(!r2.match (written, 0, out info2))
                    return false;
                var word = info2.fetch_named ("word");
                var rest = info2.fetch_named ("rest");
                bool retbool = false;
                foreach (Symbol child in children){
                    if (symbol_is_type (child, child_type)){
                        if (binding != null)
                            if (!symbol_has_binding(child, binding))
                                continue;
                        if (word == child.name){
                            var child_param = find_param (call_params, write_to_param, current_rule.rule_id);
                            if (child_param == null){
                                child_param = new CallParameter();
                                child_param.name = write_to_param;
                                child_param.for_rule_id = current_rule.rule_id;
                                call_params.add (child_param);
                            }
                            if (binding != null && binding.contains("arr_el"))
                                child_param.set_symbol(get_type_of_symbol(child, true));
                            else
                                child_param.set_symbol(child);
                            //var rets = new Gee.TreeSet<CompletionProposal>();
                            if (compare (rule[1:rule.length], accessible, rest, call_params, depth + 1, ref ret)) {
                                //ret.add_all(rets);
                                retbool = true;
                            }
                        }
                        if (rest == "" && child.name.has_prefix (word) && child.name.length > word.length){
                            ret.add (new CompletionProposal (child, word.length));
                            retbool = true;
                        }
                    }
                }
                return retbool;
            }
            if (current_rule.expr.has_prefix ("$")) {
                Regex r = /^\$(?P<call>\w*)(\{(?P<pass>(\w*|\@))\})?(\>\{(?P<ret>.*)\})?$/;
                MatchInfo info;
                if (!r.match (current_rule.expr, 0, out info)) {
                    stdout.printf ("Malformed rule! >" + compare_rule[0].expr + "<\n");
                    return false;
                }
                var call = info.fetch_named ("call");
                var pass_param = info.fetch_named ("pass");
                var ret_param = info.fetch_named ("ret");

                if (!map_syntax.has_key (call)) {
                    stdout.printf (_("Call '%s' not found in >%s<\n"), call, compare_rule[0].expr);
                    return false;
                }

                RuleExpression[] composit_rule = map_syntax[call].rule;
                rule_id_count ++;
                foreach (RuleExpression subexp in composit_rule)
                    subexp.rule_id = rule_id_count;

                foreach (RuleExpression exp in rule[1:rule.length])
                    composit_rule += exp;

                //var pass_call_params = call_params;// clone_param_list(call_params);
                if (pass_param != null) {

                    var child_param = new CallParameter();
                    child_param.name = map_syntax[call].parameters[0];
                    child_param.for_rule_id = rule_id_count;
                    var param = find_param (call_params, pass_param, current_rule.rule_id);
                    if (param == null) {
                        stdout.printf (_("Parameter '%s' not found in >%s<\n"), pass_param, compare_rule[0].expr);
                        return false;
                    }
                    child_param.add_symbols(param.symbols);
                    call_params.add (child_param);

                    if (ret_param != null){
                        var ret_p = find_param (call_params, ret_param, current_rule.rule_id);
                        if (ret_p == null){
                            ret_p = new CallParameter();
                            ret_p.name = ret_param;
                            ret_p.for_rule_id = current_rule.rule_id;
                            call_params.add (ret_p);
                        }
                        var child_ret_p = new CallParameter();
                        child_ret_p.name = "ret";
                        child_ret_p.for_rule_id = rule_id_count;
                        child_ret_p.return_to_param = ret_p;
                        call_params.add(child_ret_p);
                    }
                }
                
                //var rets = new Gee.TreeSet<CompletionProposal>();
                if(compare (composit_rule, accessible, written, call_params, depth + 1, ref ret)){
                    //ret.add_all(rets);
                    return true;
                }
                return false;
            }

            var mres = match (written, current_rule.expr);

            if (mres == matchres.COMPLETE) {
                written = written.substring (current_rule.expr.length);
                if (rule.length == 1)
                    return true;
                return compare (rule[1:rule.length], accessible, written, call_params, depth + 1, ref ret);
            }
            else if (mres == matchres.STARTED) {
                ret.add (new CompletionProposal (new Struct (current_rule.expr, null, null), written.length));
                return true;
            }
            return false;
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

        Symbol? get_type_of_symbol (Symbol smb, bool resolve_array){
            if (smb is Class || smb is Namespace || smb is Struct || smb is Enum)
                return smb;

            DataType type = null;
            if (smb is Property)
                type = ((Property) smb).property_type;
            if (smb is Variable)
                type = ((Variable) smb).variable_type;
            if (smb is Method)
                type = ((Method) smb).return_type;

            if (type == null)
                return null;
            if (type is ArrayType){
                if (resolve_array)
                    return ((ArrayType)type).element_type.data_type;
                else
                    return new Class("Array");
            }
            return type.data_type;
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
                        stderr.printf (_("Could not read line: %s"), e.message);
                    } catch (Error e) {
                        stderr.printf (_("Could not read file: %s"), e.message);
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
#if DEBUG
                stdout.printf ("Update source file: %s\n", file.filename);
#endif

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
