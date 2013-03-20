/*
 * guanako/guanako.vala
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
using Gee;

namespace Guanako {
    /**
     * Enable debug information.
     */
    public bool debug = false;

    public class CompletionProposal {
        public CompletionProposal (Symbol smb, int rep_length) {
            this.symbol = smb;
            this.replace_length = rep_length;
        }
        public Symbol symbol;
        public int replace_length;
    }

    public class Project {
        public CodeContext context { get; private set; }
        Vala.Parser parser;
        int glib_major = 2;  //TODO: Make this an option.
        int glib_minor = 32;

        /**
         * Manually added packages.
         */
        public Gee.TreeSet<string> packages { get; private set; }
        /**
         * Manually added source files.
         */
        public Gee.TreeSet<SourceFile> sourcefiles { get; private set; }

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

            if (source_file.file_type == SourceFileType.SOURCE) {
                var ns_ref = new UsingDirective (new UnresolvedSymbol (null, "GLib"));
                source_file.add_using_directive (ns_ref);
                context.root.add_using_directive (ns_ref);
            }

            context.add_source_file (source_file);
            sourcefiles.add (source_file);
            return true;
        }

        public SourceFile? get_source_file_by_name (string filename) {
            foreach (SourceFile file in context.get_source_files())
                if (file.filename == filename)
                    return file;
            return null;
        }

        public SourceFile? add_source_file_by_name (string filename, bool is_vapi = false) {
            SourceFile source_file;
            if (is_vapi)
                source_file = new SourceFile (context,
                                              SourceFileType.PACKAGE,
                                              filename);
            else
                source_file = new SourceFile (context,
                                              SourceFileType.SOURCE,
                                              filename);
            if (!add_source_file (source_file))
                return null;
            return source_file;
        }

        public void set_report_wrapper (Report report_wrapper) {
            context.report = report_wrapper;
        }

        public Project (string? filename = null) throws IOError, Error {
            context = new CodeContext();
            parser = new Vala.Parser();
            packages = new Gee.TreeSet<string>();
            sourcefiles = new Gee.TreeSet<SourceFile>();

            context_prep();

            build_syntax_map (filename);
        }

        /**
         * Set {@link Vala.CodeContext} options and flags.
         */
        private void context_prep() {
            context.target_glib_major = glib_major;
            context.target_glib_minor = glib_minor;
            for (int i = 16; i <= glib_minor; i += 2)
                context.add_define ("GLIB_%d_%d".printf (glib_major, i));
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
            sourcefiles.remove (file);
        }

        public Symbol root_symbol {
            get { return context.root; }
        }

        public string[] add_packages (string[] package_names, bool auto_update) {
            string[] missing_packages = new string[0];

            var old_deps = get_package_dependencies (packages.to_array());

            var new_deps = package_names;
            /* Collect all new dependencies coming with the new packages */
            foreach (string pkg in get_package_dependencies (package_names))
                if (!(pkg in old_deps) && !(pkg in new_deps)) {
                    var vapi_path = context.get_vapi_path (pkg);
                    if (vapi_path == null) {
                        stderr.printf (_("Warning: Vapi for package %s not found.\n"), pkg);
                        missing_packages += pkg;
                        continue;
                    }
                    debug_msg (_("Vapi found: %s\n"), vapi_path);
                    new_deps += pkg;
                }

            foreach (string package_name in package_names) {
                /* Add the new packages */
                packages.add (package_name);
                var vapi_path = context.get_vapi_path (package_name);
                if (vapi_path == null) {
                    stderr.printf (_("Warning: Vapi for package %s not found.\n"), package_name);
                    missing_packages += package_name;
                    continue;
                }
                debug_msg (_("Vapi found: %s\n"), vapi_path);
                context.add_external_package (package_name);
            }

            /* Update completion info of all the new packages */
            if (auto_update)
                foreach (string pkg in new_deps) {
                    var vapi_path = context.get_vapi_path (pkg);
                    var pkg_file = get_source_file (vapi_path);
                    if (pkg_file == null) {
                        stderr.printf (_("Could not load vapi: %s\n"), vapi_path);
                        missing_packages += pkg;
                        continue;
                    }
                    update_file (pkg_file);
                }

            return missing_packages;
        }

        public SourceFile? get_source_file (string filename) {
            foreach (SourceFile file in context.get_source_files())
                if (file.filename == filename)
                    return file;
            return null;
        }

        public void remove_package (string package_name) {
            packages.remove (package_name);
            var deps = get_package_dependencies (packages.to_array());

            var remove_candidates = get_package_dependencies (new string[] {package_name});
            remove_candidates += package_name;

            /* Collect all dependencies of package_name that are not required any more */
            var unused = new string[0];
            foreach (string pkg in remove_candidates)
                if (!(pkg in deps) && !(pkg in packages))
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

            context.resolver.resolve (context);
            context.analyzer.analyze (context);
            CodeContext.pop();
        }

        void build_syntax_map (string? filename = null) throws IOError, Error {
            string fname;
            if (filename == null)
                fname = Path.build_path (Path.DIR_SEPARATOR_S,
                                         Config.PACKAGE_DATA_DIR,
                                         "syntax");
            else
                fname = filename;
            debug_msg (_("Load syntax file: %s\n"), fname);
            var file = File.new_for_path (fname);
            var dis = new DataInputStream (file.read());
            string line;
            while ((line = dis.read_line (null)) != null) {
                if (line.strip() == "" || line.has_prefix ("#"))
                    continue;

                string[] rule_line_split = dis.read_line (null).split (" ");
                RuleExpression[] rule_exprs = new RuleExpression[rule_line_split.length];
                for (int q = 0; q < rule_line_split.length; q++) {
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

        public Gee.TreeSet<CompletionProposal>[] propose_symbols (SourceFile file,
                                                                 int line,
                                                                 int col,
                                                                 string written, out Symbol? current_symbol) {
            var accessible = get_accessible_symbols (file, line, col);
            var inside_symbol = get_symbol_at_pos (file, line, col);

            var ret = new ProposalSet();

            var comprun = new CompareRun(this);

            string initial_rule_name = "";
            Symbol[] accessible_symbols;
            if (inside_symbol == null) {
                initial_rule_name = "init_deep_space";
                accessible_symbols = get_child_symbols (context.root);
            } else {
                initial_rule_name = "init_method";
                accessible_symbols = accessible;
            }
            if (!map_syntax.has_key (initial_rule_name)) {
                stdout.printf (@"Entry point $initial_rule_name not found in syntax file. Trying to segfault me, huh??");
                return ret.comp_sets;
            }
            comprun.run (map_syntax[initial_rule_name].rule,
                            accessible_symbols,
                            written, ref ret);
            ret.wait_for_finish();
            if (comprun.cur_stack.size > 0)
                current_symbol = comprun.cur_stack.last();
            else
                current_symbol = null;
            return ret.comp_sets;
        }

        internal class RuleExpression {
            public string expr;
            public int rule_id;
            public RuleExpression clone() {
                var ret = new RuleExpression();
                ret.expr = this.expr;
                ret.rule_id = this.rule_id;
                return ret;
            }
        }

        public class ProposalSet {
            public ProposalSet() {
                // TreeSet with custom sorting function
                comp_sets = new Gee.TreeSet<CompletionProposal>[27];
                for (int q = 0; q < 27; q++)
                    comp_sets[q] = new Gee.TreeSet<CompletionProposal> ((a,b) => {
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
                thread_add_items = new Thread<void*> (_("Proposal collector"), run_thread_add_items);
            }
            ~ProposalSet() {
                active = false;
                loop_thread.quit();
            }

            bool active = true;
            void* run_thread_add_items (){
                while (active) {
                    if (queue.size == 0)
                        loop_thread.run();
                    CompletionProposal prop = null;
                    lock (queue) {
                        if (queue.size == 0)
                            continue;
                        prop = queue[0];
                        queue.remove_at (0);
                    }
                    if (prop != null) {
                        if (65 <= prop.symbol.name.data[0] <= 90)
                            comp_sets[prop.symbol.name.data[0] - 65].add (prop);
                        else if (97 <= prop.symbol.name.data[0] <= 122)
                            comp_sets[prop.symbol.name.data[0] - 97].add (prop);
                        else
                            comp_sets[26].add (prop);
                    }
                }
                return null;
            }

            public void wait_for_finish() {
                var tmr = new Timer();
                tmr.start();
                while (queue.size > 0) //TODO: Cleaner solution
                    Thread.usleep (1000);
            }

            MainLoop loop_thread = new MainLoop();
            Gee.ArrayList<CompletionProposal> queue = new Gee.ArrayList<CompletionProposal>();
            Thread<void*> thread_add_items;

            public void add (CompletionProposal prop) {
                lock (queue) {
                    queue.add (prop);
                }
                loop_thread.quit();
            }
            public void add_all (ProposalSet add_set) {
                lock (queue) {
                    foreach (var s in add_set.comp_sets)
                        queue.add_all (s);
                }
                loop_thread.quit();
            }
            public Gee.TreeSet<CompletionProposal>[] comp_sets;
        }

        class CompareRun {
            public CompareRun(Project parent_project) {
                this.parent_project = parent_project;
                universal_parameter = new CallParameter();
                universal_parameter.name = "@";
            }
            public Gee.ArrayList<Symbol> cur_stack = new Gee.ArrayList<Symbol>();
            Project parent_project;
            int rule_id_count = 0;
            Symbol[] accessible;

            private class CallParameter {
                public int for_rule_id;
                public string name;

                bool _resolve_array = false;
                public bool resolve_array{
                    get {return _resolve_array;}
                    set {
                        _resolve_array = value;
                        if (return_to_param != null)
                            return_to_param.resolve_array = value;
                    }
                }

                Symbol _symbol = null;
                public Symbol symbol{
                    get {return _symbol;}
                    set {
                        _symbol = value;
                        if (return_to_param != null)
                            return_to_param.symbol = value;
                    }
                }

                public CallParameter? return_to_param = null;
            }
            CallParameter universal_parameter;
            /*
            * Clones a list of CallParameter's, including return dependencies
            */
            Gee.ArrayList<CallParameter> clone_param_list (Gee.ArrayList<CallParameter> param) {
                var ret = new Gee.ArrayList<CallParameter>();
                foreach (CallParameter p in param) {
                    var new_param = new CallParameter();
                    new_param.for_rule_id = p.for_rule_id;
                    new_param.symbol = p.symbol;
                    new_param.name = p.name;
                    new_param.resolve_array = p.resolve_array;
                    new_param.return_to_param = p.return_to_param;
                    ret.add (new_param);
                }
                foreach (CallParameter r in ret)
                    if (r.return_to_param != null)
                        r.return_to_param = find_param (ret, r.return_to_param.name, r.return_to_param.for_rule_id);
                return ret;
            }

            private Gee.ArrayList<Symbol> clone_symbol_list (Gee.ArrayList<Symbol> list) {
                var ret = new Gee.ArrayList<Symbol>();
                ret.add_all(list);
                return ret;
            }
            private RuleExpression[] clone_rules (RuleExpression[] rules) {
                RuleExpression[] rule = new RuleExpression[rules.length];
                for (int q = 0; q < rule.length; q++)
                    rule[q] = rules[q].clone();
                return rule;
            }
            private CallParameter? find_param (Gee.ArrayList<CallParameter> array,
                                    string name,
                                    int rule_id) {
                if (name == "@")
                    return universal_parameter;
                foreach (CallParameter param in array)
                    if (param.name == name && param.for_rule_id == rule_id)
                        return param;
                return null;
            }

            public void run (RuleExpression[] compare_rule,
                                Symbol[] accessible,
                                string written,
                                ref ProposalSet ret) {
                this.accessible = accessible;
                Gee.ArrayList<Symbol> init_private_cur_stack = new Gee.ArrayList<Symbol>();
                compare (compare_rule, written, new Gee.ArrayList<CallParameter>(), 0, ref ret, ref init_private_cur_stack);
            }
            private void compare (RuleExpression[] compare_rule,
                                string written2,
                                Gee.ArrayList<CallParameter> call_params,
                                int depth, ref ProposalSet ret,
                                ref Gee.ArrayList<Symbol> private_cur_stack) {

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
                /*string depth_string = "";
                for (int q = 0; q < depth; q++)
                    depth_string += " ";
                stdout.printf ("\n" + depth_string + "Current rule: " + current_rule.expr + "\n" +
                            depth_string + "Written: " + written + "\n");*/

                if (current_rule.expr.contains ("|")) {
                    var splt = current_rule.expr.split ("|");
                    var thdlist = new Thread<void*>[0];

                    foreach (string s in splt) {
                        /*
                        * Need create a separate set of parameters here, as each branch might
                        * assign different values (resulting in scrambled eggs)
                        */
                        var r = clone_rules (rule);
                        r[0].expr = s;

                        var pass_private_cur_stack = clone_symbol_list(private_cur_stack);
                        thdlist += compare_threaded (this, r, written, clone_param_list (call_params), depth, ref ret, ref pass_private_cur_stack);
                    }
                    foreach (Thread<void*> thd in thdlist)
                        thd.join();
                    return;
                }

                if (current_rule.expr.has_prefix ("?")) {
                    var pass_private_cur_stack1 = clone_symbol_list(private_cur_stack);
                    if (rule.length > 1)
                        compare (rule[1:rule.length], written, clone_param_list (call_params), depth + 1, ref ret, ref pass_private_cur_stack1);
                    rule[0].expr = rule[0].expr.substring (1);
                    var pass_private_cur_stack2 = clone_symbol_list(private_cur_stack);
                    compare (rule, written, call_params, depth + 1, ref ret, ref pass_private_cur_stack2);
                    return;
                }

                if (current_rule.expr.has_prefix ("*word")) {
                    Regex r = /^(?P<word>\w*)(?P<rest>.*)$/;
                    MatchInfo info;
                    if (!r.match (written, 0, out info))
                        return;
                    if (info.fetch_named ("word") == null)
                        return;
                    compare (rule[1:rule.length], info.fetch_named ("rest"), call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }


                if (current_rule.expr == "_") {
                    if (!(written.has_prefix (" ") || written.has_prefix ("\t")))
                        return;
                    written = written.chug();
                    compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }

                if (current_rule.expr.has_prefix ("push_cur")) {
                    Regex r = /^push_cur\>\{(?P<param>\w*)\}$/;
                    MatchInfo info;
                    if (!r.match (current_rule.expr, 0, out info)) {
                        stdout.printf (_("Malformed rule! >%s<\n"), compare_rule[0].expr);
                        return;
                    }
                    var push_param = find_param (call_params, info.fetch_named ("param"), current_rule.rule_id);
                    private_cur_stack.add (push_param.symbol);
                    compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }
                if (current_rule.expr.has_prefix ("pop_cur")) {
                    Regex r = /^pop_cur\>\{(?P<param>\w*)\}$/;
                    MatchInfo info;
                    if (!r.match (current_rule.expr, 0, out info)) {
                        stdout.printf (_("Malformed rule! >%s<\n"), compare_rule[0].expr);
                        return;
                    }
                    var pop_param = find_param (call_params, info.fetch_named ("param"), current_rule.rule_id);
                    for (int q = private_cur_stack.size - 1; q >= 0; q--)
                        if (private_cur_stack[q] == pop_param.symbol) {
                            private_cur_stack.remove_at(q);
                            compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                            return;
                        }
                    stdout.printf (_("pop_cur symbol not found! >%s<\n"), compare_rule[0].expr);
                    return;
                }

                if (current_rule.expr.has_prefix ("{")) {
                    Regex r = /^\{(?P<parent>.*)\}\>(?P<child>\w*)(\<(?P<binding>.*)\>)?(\{(?P<write_to>\w*)\})?$/;
                    MatchInfo info;
                    if (!r.match (current_rule.expr, 0, out info)) {
                        stdout.printf (_("Malformed rule! >%s<\n"), compare_rule[0].expr);
                        return;
                    }

                    var parent_param_name = info.fetch_named ("parent");
                    var child_type = info.fetch_named ("child");
                    var binding = info.fetch_named ("binding");
                    var write_to_param = info.fetch_named ("write_to");

                    var parent_param = find_param (call_params, parent_param_name, current_rule.rule_id);
                    if (parent_param == null) {
                        stdout.printf (_("Variable '%s' not found! >%s<\n"), parent_param_name, compare_rule[0].expr);
                        return;
                    }
                    Symbol[] children = new Symbol[0];
                    if (parent_param.symbol == null) {
                        children = accessible;
                    } else {
                        //bool resolve_array = false;
                        //if (binding != null)
                        //    resolve_array = binding.contains ("arr_el");
                        //children = get_child_symbols (get_type_of_symbol (parent_param.symbol, resolve_array));
                        //children = get_child_symbols (parent_param.symbol);
                        //stdout.printf ("Getting children of " + parent_param.symbol.name + ", resolve: " + parent_param.resolve_array.to_string() + "\n");
                        children = get_child_symbols (get_type_of_symbol (parent_param.symbol, parent_param.resolve_array));
                    }

                    Regex r2 = /^(?P<word>\w*)(?P<rest>.*)$/;
                    MatchInfo info2;
                    if (!r2.match (written, 0, out info2))
                        return;
                    var word = info2.fetch_named ("word");
                    var rest = info2.fetch_named ("rest");

                    bool match_found = false;
                    foreach (Symbol child in children) {
                        if (symbol_is_type (child, child_type)) {
                            if (binding != null)
                                if (!symbol_has_binding (child, binding))
                                    continue;
                            if (word == child.name) {
                                if (write_to_param != null) {
                                    var child_param = find_param (call_params, write_to_param, current_rule.rule_id);
                                    if (child_param == null) {
                                        child_param = new CallParameter();
                                        child_param.name = write_to_param;
                                        child_param.for_rule_id = current_rule.rule_id;
                                        call_params.add (child_param);
                                    }
                                    /*if (binding != null && binding.contains ("arr_el")) {
                                        child_param.symbol = get_type_of_symbol (child, true);
                                    } else
                                        child_param.symbol = get_type_of_symbol (child, false);
                                    */
                                    child_param.symbol = child;
                                    if (binding != null && binding.contains ("arr_el")) {
                                        //stdout.printf ("Mark as resolve: " + child.name + "\n");
                                        child_param.resolve_array = true;
                                    } else {
                                        //stdout.printf ("Mark as no resolve: " + child.name + "\n");
                                        child_param.resolve_array = false;
                                    }
                                }
                                compare (rule[1:rule.length], rest, call_params, depth + 1, ref ret, ref private_cur_stack);
                            }
                            if (rest == "" && child.name.has_prefix (word) && child.name.length > word.length) {
                                match_found = true;
                                ret.add (new CompletionProposal (child, word.length));
                            }
                        }
                    }
                    if (match_found) {
                        if (private_cur_stack.size > 0)
                            cur_stack = private_cur_stack;
                    }
                    return;
                }
                if (current_rule.expr.has_prefix ("$")) {
                    Regex r = /^\$(?P<call>\w*)(\{(?P<pass>(\w*|\@))\})?(\>\{(?P<ret>.*)\})?$/;
                    MatchInfo info;
                    if (!r.match (current_rule.expr, 0, out info)) {
                        stdout.printf (_("Malformed rule! >%s<\n"), compare_rule[0].expr);
                        return;
                    }
                    var call = info.fetch_named ("call");
                    var pass_param = info.fetch_named ("pass");
                    var ret_param = info.fetch_named ("ret");

                    if (!parent_project.map_syntax.has_key (call)) {
                        stdout.printf (_("Call '%s' not found in >%s<\n"), call, compare_rule[0].expr);
                        return;
                    }

                    RuleExpression[] composit_rule = parent_project.map_syntax[call].rule;
                    int local_rule_id_count;
                    lock (rule_id_count) {
                        rule_id_count ++;
                        local_rule_id_count = rule_id_count;
                    }
                    foreach (RuleExpression subexp in composit_rule)
                        subexp.rule_id = local_rule_id_count;

                    foreach (RuleExpression exp in rule[1:rule.length])
                        composit_rule += exp;

                    if (pass_param != null && pass_param != "") {

                        var child_param = new CallParameter();
                        child_param.name = parent_project.map_syntax[call].parameters[0];
                        child_param.for_rule_id = local_rule_id_count;
                        var param = find_param (call_params, pass_param, current_rule.rule_id);
                        if (param == null) {
                            stdout.printf (_("Parameter '%s' not found in >%s<\n"), pass_param, compare_rule[0].expr);
                            return;
                        }
                        child_param.symbol = param.symbol;
                        call_params.add (child_param);

                    }
                    if (ret_param != null) {
                        var ret_p = find_param (call_params, ret_param, current_rule.rule_id);
                        if (ret_p == null) {
                            ret_p = new CallParameter();
                            ret_p.name = ret_param;
                            ret_p.for_rule_id = current_rule.rule_id;
                            call_params.add (ret_p);
                        }
                        var child_ret_p = new CallParameter();
                        child_ret_p.name = "ret";
                        child_ret_p.for_rule_id = local_rule_id_count;
                        child_ret_p.return_to_param = ret_p;
                        call_params.add (child_ret_p);
                    }

                    compare (composit_rule, written, call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }

                var mres = match (written, current_rule.expr);

                if (mres == MatchRes.COMPLETE) {
                    written = written.substring (current_rule.expr.length);
                    if (rule.length == 1)
                        return;
                    compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                }
                else if (mres == MatchRes.STARTED) {
                    if (private_cur_stack.size > 0)
                        cur_stack = private_cur_stack;
                    ret.add (new CompletionProposal (new Struct (current_rule.expr, null, null), written.length));
                }
                return;
            }

            Symbol? get_type_of_symbol (Symbol smb, bool resolve_array) {
                if (smb is Class || smb is Namespace || smb is Struct || smb is Enum)
                    return smb;

                DataType type = null;
                if (smb is Property)
                    type = ((Property) smb).property_type;
                else if (smb is Variable)
                    type = ((Variable) smb).variable_type;
                else if (smb is Method)
                    type = ((Method) smb).return_type;

                if (type == null)
                    return null;
                if (type is ArrayType) {
                    if (resolve_array)
                        return ((ArrayType)type).element_type.data_type;
                    else
                        return new Class ("Array");
                }
                return type.data_type;
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

            bool symbol_has_binding (Symbol smb, string? binding) {
                if (binding == null)
                    return true;

                bool stat = binding.contains ("static");
                bool inst = binding.contains ("instance");
                bool arr = binding.contains ("array") || binding.contains ("arr_el");
                bool sng = binding.contains ("single");

                MemberBinding smb_binding = 0;
                if (smb is Method)
                    smb_binding = ((Method)smb).binding;
                else if (smb is Field)
                    smb_binding = ((Field)smb).binding;
                else if (smb is Property)
                    smb_binding = ((Property)smb).binding;

                if (inst && smb_binding == MemberBinding.STATIC)
                    return false;
                if (stat && smb_binding == MemberBinding.INSTANCE)
                    return false;

                DataType type = null;
                if (smb is Property)
                    type = ((Property) smb).property_type;
                else if (smb is Variable)
                    type = ((Variable) smb).variable_type;
                else if (smb is Method)
                    type = ((Method) smb).return_type;
                if (type != null) {
                    if (!type.is_array() && arr)
                        return false;
                    if (type.is_array() && sng)
                        return false;
                }
                return true;
            }
            enum MatchRes {
                UNEQUAL,
                STARTED,
                COMPLETE
            }

            MatchRes match (string written, string target) {
                if (written.length >= target.length)
                    if (written.has_prefix (target))
                        return MatchRes.COMPLETE;
                if (target.length > written.length && target.has_prefix (written))
                    return MatchRes.STARTED;
                return MatchRes.UNEQUAL;
            }

            Thread<void*> compare_threaded (CompareRun comp_run,
                                            RuleExpression[] compare_rule,
                                            string written,
                                            Gee.ArrayList<CallParameter> call_params,
                                            int depth,
                                            ref ProposalSet ret, ref Gee.ArrayList<Symbol> private_cur_stack) {
                var compare_thd = new CompareThread (comp_run, compare_rule, written, call_params, depth, ref ret, ref private_cur_stack);
                return new Thread<void*> (_("Guanako Completion"), compare_thd.run);
            }

            class CompareThread {
                public CompareThread (CompareRun comp_run,
                                    RuleExpression[] compare_rule,
                                    string written,
                                    Gee.ArrayList<CallParameter> call_params,
                                    int depth,
                                    ref ProposalSet ret, ref Gee.ArrayList<Symbol> private_cur_stack) {
                    this.comp_run = comp_run;
                    this.compare_rule = compare_rule;
                    this.call_params = call_params;
                    this.depth = depth;
                    this.written = written;
                    this.private_cur_stack = private_cur_stack;
                    this.ret = ret;
                }
                CompareRun comp_run;
                RuleExpression[] compare_rule;
                Gee.ArrayList<CallParameter> call_params;
                ProposalSet ret;
                int depth;
                string written;
                Gee.ArrayList<Symbol> private_cur_stack;
                public void* run() {
                    comp_run.compare (compare_rule, written, call_params, depth + 1, ref ret, ref private_cur_stack);
                    return null;
                }
            }
        }

        public Symbol[] get_accessible_symbols (SourceFile file, int line, int col) {
            Symbol [] ret = new Symbol[0];
            var current_symbol = get_symbol_at_pos (file, line, col);

            if (current_symbol == null)
                return ret;

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

                iter_subroutine (sr, (statement, depth) => {
                    if (inside_source_ref (file, line, col, statement.source_reference)) {
                        if (depth > last_depth)
                            last_depth = depth;
                        return IterCallbackReturns.ABORT_TREE;
                    }
                    if (before_source_ref (file, line, col, statement.source_reference)) {
                        if (depth > last_depth)
                            last_depth = depth;
                        return IterCallbackReturns.ABORT_TREE;
                    }
                    if (statement is DeclarationStatement || statement is ForeachStatement) {
                        candidates += statement;
                        depths += depth;
                    }
                    return IterCallbackReturns.CONTINUE;
                });

                /*
                 * Return all candidates with a lower or equal depth.
                 */
                for (int q = candidates.length - 1; q >= 0; q--) {
                    if (depths[q] <= last_depth || last_depth == -1) {
                        /*if (candidates[q] is ForStatement) {
                            var expressions = ((ForStatement) candidates[q]).get_initializer();
                            foreach (Expression expr in expressions) {
                                stdout.printf (expr.symbol_reference.name + "!!\n");
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
            iter_symbol (context.root,
                         (smb, depth) => {
                            if (smb.name != null) {
                                SourceReference sref = smb.source_reference;
                                if (sref == null)
                                    return IterCallbackReturns.CONTINUE;

                                /*
                                 * Check symbol's own source reference.
                                 */
                                if (inside_source_ref (source_file, line, col, sref)) {
                                    if (depth > last_depth) {  //Get symbol deepest in the tree
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
                            return IterCallbackReturns.CONTINUE;
                         });
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
            foreach (var node in file.get_nodes())
                nodes.add (node);
            foreach (var node in nodes) {
                file.remove_node (node);
                if (node is Vala.Symbol) {
                    var sym = (Vala.Symbol) node;
                    if (sym.owner != null)
                        /*
                         * We need to remove it from the scope.
                         */
                        sym.owner.remove (sym.name);
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
                 * due to read-only list).
                 */
                debug_msg ("Update source file: %s\n", file.filename);

                Vala.CodeContext.push (context);

                vanish_file (file);

                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                if (file.file_type == SourceFileType.SOURCE) {
                    var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                    file.add_using_directive (ns_ref);
                    context.root.add_using_directive (ns_ref);
                }

                parser.visit_source_file (file);

                context.resolver.resolve (context);
                context.analyzer.visit_source_file (file);
                context.check();

                Vala.CodeContext.pop();
            }
        }
     }

    /**
     * Print debug information if {@link debug} is `true`.
     *
     * @param format Format string.
     * @param ... Arguments for format string.
     */
    private void debug_msg (string format, ...) {
        if (debug)
            stdout.printf (format.vprintf (va_list()));

    }
}

// vim: set ai ts=4 sts=4 et sw=4
