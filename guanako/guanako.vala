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

    public static void init (bool reload = false) {
        load_vapi_dirs (reload);
        load_available_packages (reload);
    }

    public class CompletionProposal {
        public CompletionProposal (Symbol smb, int rep_length) {
            this.symbol = smb;
            this.replace_length = rep_length;
        }
        public Symbol symbol;
        public int replace_length;
    }

    public class Project {
        CodeContext context;
        CodeContext context_internal;
        ParserExt parser;
        int glib_major;
        int glib_minor;
        Type? manual_report;
        bool initialized = false;

        /**
         * Manually added packages.
         */
        public TreeSet<string> packages { get; private set; }
        /**
         * Manually added source files.
         */
        public TreeSet<SourceFile> sourcefiles { get; private set; }

        /**
         * All enabled defines.
         */
        public TreeSet<string> defines { get; private set; }
        /**
         * Manually enabled defines.
         */
        public TreeSet<string> defines_manual { get; private set; }


        public Project (string? filename = null,
                        int glib_major = 2, int glib_minor = 18) throws IOError, Error {
            context_internal = new CodeContext();
            parser = new ParserExt();
            packages = new TreeSet<string>();
            sourcefiles = new TreeSet<SourceFile>();
            defines = new TreeSet<string>();
            defines_manual = new TreeSet<string>();
            context_internal.report = new Reporter();
            manual_report = null;

            this.glib_major = glib_major;
            this.glib_minor = glib_minor;

            context_prep (context_internal, glib_major, glib_minor, define_action_int);
            context = context_internal;

            build_syntax_map (filename);
        }

        public delegate void DefineAction (string define);

        private inline void define_action_int (string define) {
            defines.add (define);
        }

        /**
         * Set {@link Vala.CodeContext} options and flags.
         */
        public static void context_prep (CodeContext context,
                                         int? glib_major = null,
                                         int? glib_minor = null,
                                         DefineAction? action = null) {
            context.target_glib_major = (glib_major != null) ? glib_major : 2;
            context.target_glib_minor = (glib_minor != null) ? glib_minor : 18;
            for (int i = 2; i <= context.target_glib_major; ++i)
                for (int j = 16; j <= context.target_glib_minor; j += 2) {
                    var define = "GLIB_%d_%d".printf (i, j);
                    context.add_define (define);
                    if (action != null)
                        action (define);
                }
            var vala_ver = Config.VALA_VERSION.split (".", 2);
            if (vala_ver[0] != null && vala_ver[1] != null)
                for (int i = 0; i <= int.parse (vala_ver[0]); ++i)
                    for (int j = 2; j <= int.parse (vala_ver[1]); j += 2) {
                        var define = "VALA_%d_%d".printf (i, j);
                        context.add_define (define);
                        if (action != null)
                            action (define);
                    }
            else
                errmsg (_("Not a valid Vala version, will  not set VALA_X_Y defines: %s\n"),
                               Config.VALA_VERSION);
            context.profile = Profile.GOBJECT;
            context.add_define ("GOBJECT");
            if (action != null)
                action ("GOBJECT");
        }

        public void set_glib_version (int glib_major, int glib_minor) {
            this.glib_major = glib_major;
            this.glib_minor = glib_minor;
        }

        public int[] get_glib_version() {
            return new int[] {glib_major, glib_minor};
        }

        public inline SourceFile[] get_source_files (bool vapis = false) {
            lock (context)
                return get_source_files_int (context, vapis);
        }

        /*
         * Not a beautiful piece of code, but necessary to convert from
         * Vala.List.
         */
        private SourceFile[] get_source_files_int (CodeContext context, bool vapis = false) {
            SourceFile[] files = new SourceFile[0];
            foreach (SourceFile file in context.get_source_files())
                if (vapis || file.file_type == SourceFileType.SOURCE)
                    files += file;
            return files;
        }

        public inline SourceFile[] get_vapis() {
            lock (context)
                return get_vapis_int (context);
        }

        private SourceFile[] get_vapis_int (CodeContext context) {
            SourceFile[] files = new SourceFile[0];
            foreach (SourceFile file in context.get_source_files())
                if (file.file_type == SourceFileType.PACKAGE)
                    files += file;
            return files;
        }

        private bool add_source_file_int (SourceFile source_file) {
            foreach (SourceFile file in get_source_files_int (context_internal, true))
                if (file.filename == source_file.filename)
                    return false;

            switch (source_file.file_type) {
                case SourceFileType.SOURCE:
                    var ns_ref = new UsingDirective (new UnresolvedSymbol (null, "GLib"));
                    source_file.add_using_directive (ns_ref);
                    context_internal.root.add_using_directive (ns_ref);
                    break;
                case SourceFileType.PACKAGE:
                    var basename = Path.get_basename (source_file.filename);
                    context_internal.add_package (basename.substring(0, basename.length - 5));
                    break;
                default:
                    break;
            }

            context_internal.add_source_file (source_file);
            sourcefiles.add (source_file);
            return true;
        }

        public SourceFile? get_source_file_by_name (string filename) {
            lock (context)
                foreach (SourceFile file in context.get_source_files())
                    if (file.filename == filename)
                        return file;
            return null;
        }

        public SourceFile? add_source_file_by_name (string filename, bool is_vapi = false) {
            lock (context_internal) {
                SourceFile source_file;
                if (is_vapi)
                    source_file = new SourceFile (context_internal,
                                                  SourceFileType.PACKAGE,
                                                  filename);
                else
                    source_file = new SourceFile (context_internal,
                                                  SourceFileType.SOURCE,
                                                  filename);
                if (!add_source_file_int (source_file))
                    return null;
                else if (is_vapi)
                    debug_msg (_("Vapi found: %s\n"), filename);
                lock (context)
                    context = context_internal;
                return source_file;
            }
        }

        public inline void set_reporter (Type reptype) {
            if (reptype.is_a (typeof (Reporter))) {
                /* Don't overwrite errorlist if reporter is set later. */
                // lock (context) {
                    manual_report = reptype;
                //     context.report = Object.new (reptype) as Reporter;
                // }
            } else
                manual_report = null;
        }

        public inline Gee.ArrayList<Reporter.Error> get_errorlist() {
            lock (context)
                return (context.report as Reporter).errlist;
        }

        /*
         * Update context manually.
         */
        public inline bool add_define (string define) {
            if (!defines.add (define))
                return false;
            defines_manual.add (define);
            return true;  // also if already defined
        }

        public inline void commit_defines() {
            lock (context_internal) {
                foreach (var define in defines_manual)
                    context_internal.add_define (define);
                lock (context)
                    context = context_internal;
            }
        }

        public inline bool remove_define (string define) {
            return remove_defines (new string[] {define});
        }

        public inline bool remove_defines (string[] defines) {
            bool found = false;
            foreach (var define in defines)
                if (define in defines_manual) {
                    found = true;
                    break;
                }
            if (!found)
                return false;
            update_complete ({}, {}, defines);
            return true;
        }

        public inline bool remove_file (SourceFile file) {
            return remove_files (new SourceFile[] {file});
        }

        public inline bool remove_files (SourceFile[] files) {
            var flist = new string[0];
            foreach (var file in files)
                foreach (var sf in sourcefiles)
                    if (file.filename == sf.filename)
                        flist += file.filename;
            if (flist.length == 0)
                return false;
            update_complete (flist);
            return true;
        }

        public Symbol root_symbol {
            get {
                lock (context)
                    return context.root;
            }
        }

        public string[] add_packages (string[] package_names, bool auto_update) {
            lock (context_internal) {
                string[] missing_packages = new string[0];

                var old_deps = get_package_dependencies_int (context_internal, packages.to_array());
                foreach (var pkg in packages)
                    if (!(pkg in old_deps))
                        old_deps += pkg;

                var new_deps = new string[0];

                /* Collect all new dependencies coming with the new packages */
                foreach (var pkg in get_package_dependencies_int (context_internal, package_names))
                    if (!(pkg in old_deps) && !(pkg in new_deps)) {
                        var vapi_path = context_internal.get_vapi_path (pkg);
                        if (vapi_path == null) {
                            warning_msg (_("Vapi for package %s not found.\n"), pkg);
                            missing_packages += pkg;
                            continue;
                        }
                        debug_msg (_("Vapi found: %s\n"), vapi_path);
                        context_internal.add_external_package (pkg);
                        new_deps += pkg;
                    }

                foreach (var pkg in package_names) {
                    /* Add the new packages that aren't dependencies. */
                    if (!(pkg in new_deps)) {
                        var vapi_path = context_internal.get_vapi_path (pkg);
                        if (vapi_path == null) {
                            warning_msg (_("Vapi for package %s not found.\n"), pkg);
                            missing_packages += pkg;
                            continue;
                        }
                        debug_msg (_("Vapi found: %s\n"), vapi_path);
                        context_internal.add_external_package (pkg);
                        new_deps += pkg;
                    }
                    packages.add (pkg);
                }

                /* Update completion info of all the new packages */
                if (auto_update)
                    foreach (var pkg in new_deps) {
                        var vapi_path = context_internal.get_vapi_path (pkg);
                        var pkg_file = get_source_file_int (context_internal, vapi_path);
                        if (pkg_file == null) {
                            errmsg (_("Could not load vapi: %s\n"), vapi_path);
                            missing_packages += pkg;
                            packages.remove (pkg);
                            continue;
                        }
                        update_file (pkg_file);
                    }

                lock (context)
                    context = context_internal;
                return missing_packages;
            }
        }

        public inline SourceFile? search_pkg (string pkg) {
            lock (context)
                return search_pkg_int (context, pkg);
        }

        private SourceFile? search_pkg_int (CodeContext context, string pkg) {
            foreach (var file in context.get_source_files())
                if (file.file_type == SourceFileType.PACKAGE) {
                    var basename = Path.get_basename (file.filename);
                    if (basename.substring (0, basename.length - 5) == pkg)
                        return file;
                }
            return null;
        }

        public inline SourceFile? get_source_file (string filename) {
            lock (context)
                return get_source_file_int (context, filename);
        }

        private SourceFile? get_source_file_int (CodeContext context, string filename) {
            foreach (SourceFile file in context.get_source_files())
                if (file.filename == filename)
                    return file;
            return null;
        }

        public void remove_package (string package_name) {
            lock (context_internal) {
                packages.remove (package_name);
                var deps = get_package_dependencies_int (context_internal, packages.to_array());

                var remove_candidates = get_package_dependencies_int (context_internal, new string[] {package_name});
                remove_candidates += package_name;

                /* Collect all dependencies of package_name that are not required any more */
                var unused = new string[0];
                foreach (string pkg in remove_candidates)
                    if (!(pkg in deps) && !(pkg in packages))
                        unused += pkg;

                foreach (string pkg in unused) {
                    packages.remove (pkg);
                    var pkg_file = get_source_file_int (context_internal, context.get_vapi_path (pkg));
                    if (pkg_file == null)
                        continue;
                    vanish_file (pkg_file);
                }

                lock (context)
                    context = context_internal;
            }
        }

        public inline void update() {
            update_complete();
        }

        private void update_complete (string[] rm_files = {},
                                      string[] rm_pkgs = {},
                                      string[] rm_defines = {}) {
            lock (context_internal) {
                var old_sourcefiles = sourcefiles;
                var old_packages = context_internal.get_packages();
                sourcefiles = new TreeSet<SourceFile>();
                foreach (var define in rm_defines)
                    if (defines_manual.remove (define))
                        defines.remove (define);

                context_internal = new CodeContext();
                context_prep (context_internal, glib_major, glib_minor, define_action_int);

                parser = new ParserExt();
                foreach (var sf in old_sourcefiles) {
                    if (sf.filename in rm_files)
                        continue;
                    var sf_new = new SourceFile (context_internal,
                                                 sf.file_type,
                                                 sf.filename,
                                                 sf.content,
                                                 sf.from_commandline);
                    switch (sf.file_type) {
                        case SourceFileType.SOURCE:
                            var ns_ref = new UsingDirective (new UnresolvedSymbol (null, "GLib"));
                            sf_new.add_using_directive (ns_ref);
                            context_internal.root.add_using_directive (ns_ref);
                            break;
                        case SourceFileType.PACKAGE:
                            var basename = Path.get_basename (sf.filename);
                            context_internal.add_package (basename.substring(0, basename.length - 5));
                            break;
                        default:
                            break;
                    }
                    context_internal.add_source_file (sf_new);
                    sourcefiles.add (sf_new);
                }
                //TODO: Use packages from context.get_source_files directly.
                foreach (var pkg in old_packages) {
                    if (pkg in rm_pkgs)
                        continue;
                    context_internal.add_external_package (pkg);
                }
                foreach (var define in defines_manual)
                    context_internal.add_define (define);

                update_int();
                lock (context)
                    context = context_internal;
            }
        }

        public inline void init() {
            if (!initialized)
                lock (context_internal) {
                    initialized = true;
                    update_int();
                    lock (context)
                        context = context_internal;
                }
        }

        private void update_int() {
            if (manual_report == null)
                context_internal.report = new Reporter();
            else
                context_internal.report = Object.new (manual_report) as Reporter;

            CodeContext.push (context_internal);
            parser.parse (context_internal);

            context_internal.resolver.resolve (context_internal);
            context_internal.analyzer.analyze (context_internal);
            context_internal.flow_analyzer.analyze (context_internal);
            CodeContext.pop();
        }

        void vanish_file (SourceFile file) {
            var nodes = new Gee.LinkedList<Vala.CodeNode>();
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
                    if (context_internal.entry_point == sym)
                        context_internal.entry_point = null;
                    sym.name = "";  //TODO: Find a less stupid solution...
                }
            }
        }

        public void update_file (Vala.SourceFile file, string? new_content = null) {
            if (new_content != null)
                file.content = new_content;
            lock (context_internal) {
                /*
                 * Removing nodes in the same loop causes problems (probably
                 * due to read-only list).
                 */
                debug_msg ("Update source file: %s\n", file.filename);
                (context_internal.report as Reporter).reset_file (file.filename);

                vanish_file (file);

                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                if (file.file_type == SourceFileType.SOURCE) {
                    var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                    file.add_using_directive (ns_ref);
                    context_internal.root.add_using_directive (ns_ref);
                }

                CodeContext.push (context_internal);
                parser.parse_file (file);

                context_internal.resolver.resolve (context_internal);
                context_internal.analyzer.visit_source_file (file);
                context_internal.flow_analyzer.visit_source_file (file);

                CodeContext.pop();

                lock (context)
                    context = context_internal;
                debug_msg ("Source file update finished.\n");
            }
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
                comp_sets = new TreeSet<CompletionProposal>[27];
                for (int q = 0; q < 27; q++)
                    comp_sets[q] = new TreeSet<CompletionProposal> ((a,b) => {
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
                // TRANSLATORS: Collector for completion proposals.
                // This string is normally not visible.
                thread_add_items = new Thread<void*> (_("Proposal collector"), run_thread_add_items);
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
                            comp_sets[prop.symbol.name.data[0] - 64].add (prop);
                        else if (97 <= prop.symbol.name.data[0] <= 122)
                            comp_sets[prop.symbol.name.data[0] - 96].add (prop);
                        else
                            comp_sets[0].add (prop);
                    }
                }
                return null;
            }

            public void wait_for_finish() {
                while (queue.size > 0) { //TODO: Cleaner solution
                    Thread.usleep (1000);
                }
                active = false;
                loop_thread.quit();
            }

            MainLoop loop_thread = new MainLoop();
            Gee.LinkedList<CompletionProposal> queue = new Gee.LinkedList<CompletionProposal>();
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
            public TreeSet<CompletionProposal>[] comp_sets;
        }

        public class CompletionRun {
            public CompletionRun(Project parent_project) {
                this.parent_project = parent_project;
                universal_parameter = new CallParameter();
                universal_parameter.name = "@";
            }
            public Gee.LinkedList<Symbol> cur_stack = new Gee.LinkedList<Symbol>();
            Project parent_project;
            int rule_id_count = 0;
            Symbol[] accessible;
            bool abort_flag = false;

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
            Gee.LinkedList<CallParameter> clone_param_list (Gee.LinkedList<CallParameter> param) {
                var ret = new Gee.LinkedList<CallParameter>();
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

            private Gee.LinkedList<Symbol> clone_symbol_list (Gee.LinkedList<Symbol> list) {
                var ret = new Gee.LinkedList<Symbol>();
                ret.add_all(list);
                return ret;
            }

            private RuleExpression[] clone_rules (RuleExpression[] rules) {
                RuleExpression[] rule = new RuleExpression[rules.length];
                for (int q = 0; q < rule.length; q++)
                    rule[q] = rules[q].clone();
                return rule;
            }

            private CallParameter? find_param (Gee.LinkedList<CallParameter> array,
                                    string name,
                                    int rule_id) {
                if (name == "@")
                    return universal_parameter;
                foreach (CallParameter param in array)
                    if (param.name == name && param.for_rule_id == rule_id)
                        return param;
                return null;
            }

            public void abort_run () {
                abort_flag = true;
            }

            public TreeSet<CompletionProposal>[]? run (SourceFile file, int line, int col, string written) {
                var inside_symbol = parent_project.get_symbol_at_pos (file, line, col);

                string initial_rule_name = "";
                if (inside_symbol == null)
                    initial_rule_name = "init_deep_space";
                else
                    initial_rule_name = "init_method";
                accessible = parent_project.get_accessible_symbols (file, line, col);

                if (!parent_project.map_syntax.has_key (initial_rule_name)) {
                    error_msg (_("Entry point '%s' not found in syntax file. Trying to segfault me, huh??"), initial_rule_name);
                    return null;
                }
                Gee.LinkedList<Symbol> init_private_cur_stack = new Gee.LinkedList<Symbol>();

                var ret = new ProposalSet();
                compare (parent_project.map_syntax[initial_rule_name].rule, written, new Gee.LinkedList<CallParameter>(), 0, ref ret, ref init_private_cur_stack);
                ret.wait_for_finish();
                if (abort_flag)
                    return null;
                return ret.comp_sets;
            }
            private void compare (RuleExpression[] compare_rule,
                                string written2,
                                Gee.LinkedList<CallParameter> call_params,
                                int depth, ref ProposalSet ret,
                                ref Gee.LinkedList<Symbol> private_cur_stack) {
                if (abort_flag)
                    return;
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
                    if (info.fetch_named ("word") == "")
                        return;
                    if (rule.length == 1)
                        return;
                    compare (rule[1:rule.length], info.fetch_named ("rest"), call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }

                if (current_rule.expr.has_prefix ("*number")) {
                    Regex r = /^(?P<number>\d*)(?P<rest>.*)$/;
                    MatchInfo info;
                    if (!r.match (written, 0, out info))
                        return;
                    if (info.fetch_named ("number") == null)
                        return;
                    if (rule.length == 1)
                        return;
                    compare (rule[1:rule.length], info.fetch_named ("rest"), call_params, depth + 1, ref ret, ref private_cur_stack);
                    return;
                }

                if (current_rule.expr.has_prefix ("*string")) {
                    Regex r = /^(?P<word>.*?)+(?=\")(?P<rest>.*)$/; //"// (This extra "// stuff is just to get gtksourceview's highlighting back on track...)
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
                        errmsg (_("Malformed rule: '%s'\n"), compare_rule[0].expr);
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
                        errmsg (_("Malformed rule: '%s'\n"), compare_rule[0].expr);
                        return;
                    }
                    var pop_param = find_param (call_params, info.fetch_named ("param"), current_rule.rule_id);
                    for (int q = private_cur_stack.size - 1; q >= 0; q--)
                        if (private_cur_stack[q] == pop_param.symbol) {
                            private_cur_stack.remove_at(q);
                            compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                            return;
                        }
                    warning_msg (_("pop_cur symbol not found! '%s'\n"), compare_rule[0].expr);
                    return;
                }

                if (current_rule.expr.has_prefix ("{")) {
                    Regex r = /^\{(?P<parent>.*)\}\>(?P<child>\w*)(\<(?P<binding>.*)\>)?(\{(?P<write_to>\w*)\})?$/;
                    MatchInfo info;
                    if (!r.match (current_rule.expr, 0, out info)) {
                        errmsg (_("Malformed rule: '%s'\n"), compare_rule[0].expr);
                        return;
                    }

                    var parent_param_name = info.fetch_named ("parent");
                    var child_type = info.fetch_named ("child");
                    var binding = info.fetch_named ("binding");
                    var write_to_param = info.fetch_named ("write_to");

                    var parent_param = find_param (call_params, parent_param_name, current_rule.rule_id);
                    if (parent_param == null) {
                        errmsg (_("Variable '%s' not found! >%s<\n"), parent_param_name, compare_rule[0].expr);
                        return;
                    }
                    Vala.List<Symbol>[] children;
                    if (parent_param.symbol == null) {
                        children = new Vala.List<Symbol>[1];
                        children[0] = new Vala.ArrayList<Symbol>();
                        foreach (Symbol child in accessible)
                            if (symbol_is_type (child, child_type))
                                children[0].add(child);
                    } else {
                        children = get_child_symbols_of_type (get_type_of_symbol (parent_param.symbol, parent_param.resolve_array), child_type);
                    }

                    Regex r2 = /^(?P<word>\w*)(?P<rest>.*)$/;
                    MatchInfo info2;
                    if (!r2.match (written, 0, out info2))
                        return;
                    var word = info2.fetch_named ("word");
                    var rest = info2.fetch_named ("rest");

                    var thdlist = new Thread<void*>[0];
                    bool match_found = false;
                    foreach (Vala.List<Symbol> list in children)
                        foreach (Symbol child in list) {
                            if (binding != null)
                                if (!symbol_has_binding (child, binding))
                                    continue;
                            if (word == child.name) {
                                if (write_to_param != null) {
                                    var target_param = find_param (call_params, write_to_param, current_rule.rule_id);
                                    if (target_param == null) {
                                        target_param = new CallParameter();
                                        target_param.name = write_to_param;
                                        target_param.for_rule_id = current_rule.rule_id;
                                        call_params.add (target_param);
                                    }
                                    target_param.symbol = child;
                                    target_param.resolve_array = binding != null && binding.contains ("arr_el");
                                }
                                thdlist += compare_threaded (this, rule[1:rule.length], rest, call_params, depth + 1, ref ret, ref private_cur_stack);
                            }
                            if (rest == "" && child.name.has_prefix (word) && child.name.length > word.length) {
                                match_found = true;
                                ret.add (new CompletionProposal (child, word.length));
                            }
                        }
                    foreach (Thread<void*> thd in thdlist)
                        thd.join();
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
                        errmsg (_("Malformed rule: '%s'\n"), compare_rule[0].expr);
                        return;
                    }
                    var call = info.fetch_named ("call");
                    var pass_param = info.fetch_named ("pass");
                    var ret_param = info.fetch_named ("ret");

                    if (!parent_project.map_syntax.has_key (call)) {
                        errmsg (_("Call '%s' not found in '%s'\n"), call, compare_rule[0].expr);
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
                            errmsg (_("Parameter '%s' not found in '%s'\n"), pass_param, compare_rule[0].expr);
                            return;
                        }
                        child_param.symbol = param.symbol;
                        child_param.resolve_array = param.resolve_array;
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

                var matchstr = current_rule.expr;
                if (matchstr.has_prefix("~"))
                    matchstr = matchstr.substring(1);
                var mres = match (written, matchstr);

                if (mres == MatchRes.COMPLETE) {
                    written = written.substring (matchstr.length);
                    if (rule.length == 1)
                        return;
                    compare (rule[1:rule.length], written, call_params, depth + 1, ref ret, ref private_cur_stack);
                }
                else if (mres == MatchRes.STARTED) {
                    if (private_cur_stack.size > 0)
                        cur_stack = private_cur_stack;
                    ret.add (new CompletionProposal (new Struct (matchstr, null, null), written.length));
                }
                return;
            }

            static Symbol? get_type_of_symbol (Symbol smb, bool resolve_array) {
                if (smb is Class || smb is Namespace || smb is Struct || smb is Enum)
                    return smb;

                DataType type = null;
                if (smb is Property)
                    type = ((Property) smb).property_type;
                else if (smb is Variable)
                    type = ((Variable) smb).variable_type;
                else if (smb is Method)
                    type = ((Method) smb).return_type;
                else
                    return null;

                if (type is ArrayType) {
                    if (resolve_array)
                        return ((ArrayType)type).element_type.data_type;
                    else
                        return new Class ("Array");
                }
                return type.data_type;
            }

            static bool symbol_is_type (Symbol smb, string type) {
                if (type == "Parameter" && smb is Vala.Parameter)
                    return true;
                // Simply treat LocalVariables as fields
                if (type == "Field" && (smb is Field || smb is LocalVariable || smb is Vala.Parameter))
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

            static bool symbol_has_binding (Symbol smb, string? binding) {
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

            Thread<void*> compare_threaded (CompletionRun comp_run,
                                            RuleExpression[] compare_rule,
                                            string written,
                                            Gee.LinkedList<CallParameter> call_params,
                                            int depth,
                                            ref ProposalSet ret, ref Gee.LinkedList<Symbol> private_cur_stack) {
                var compare_thd = new CompareThread (comp_run, compare_rule, written, call_params, depth, ref ret, ref private_cur_stack);
                return new Thread<void*> (_("Guanako Completion"), compare_thd.run);
            }

            class CompareThread {
                public CompareThread (CompletionRun comp_run,
                                    RuleExpression[] compare_rule,
                                    string written,
                                    Gee.LinkedList<CallParameter> call_params,
                                    int depth,
                                    ref ProposalSet ret, ref Gee.LinkedList<Symbol> private_cur_stack) {
                    this.comp_run = comp_run;
                    this.compare_rule = compare_rule;
                    this.call_params = call_params;
                    this.depth = depth;
                    this.written = written;
                    this.private_cur_stack = private_cur_stack;
                    this.ret = ret;
                }
                CompletionRun comp_run;
                RuleExpression[] compare_rule;
                Gee.LinkedList<CallParameter> call_params;
                ProposalSet ret;
                int depth;
                string written;
                Gee.LinkedList<Symbol> private_cur_stack;
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
                current_symbol = context.root;

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
                        return IterCallbackReturns.CONTINUE;
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
            lock (context)
                iter_symbol (context.root,
                             (smb, depth) => {
                                if (smb.name != null) {
                                    SourceReference sref = smb.source_reference;
                                    if (sref == null)
                                        return IterCallbackReturns.CONTINUE;

                                    /*
                                     * If the symbol is a subroutine, check its body's source
                                     * reference.
                                     */
                                    if (smb is Subroutine) {
                                        var sr = (Subroutine) smb;
                                        if (sr.body != null)
                                            sref = sr.body.source_reference;
                                    }

                                    /*
                                     * Check source reference, do not check its children if outside
                                     */
                                    if (inside_source_ref (source_file, line, col, sref)) {
                                        if (depth > last_depth) {  //Get symbol deepest in the tree
                                            ret = smb;
                                            last_depth = depth;
                                        }
                                    } else if (smb is Subroutine)
                                        return IterCallbackReturns.ABORT_BRANCH;

                                }
                                return IterCallbackReturns.CONTINUE;
                             });
            return ret;
        }

        public string[] get_package_dependencies (string[] package_names) {
            lock (context)
                return get_package_dependencies_int (context, package_names);
        }

        private string[] get_package_dependencies_int (CodeContext context, string[] package_names) {
            var deps = new ArrayQueue<string>();
            var skip_pkgs = new string[0];  // circular dependencies

            foreach (var package_name in package_names) {
                if (package_name in skip_pkgs)
                    continue;

                var vapi_path = context.get_vapi_path (package_name);
                if (vapi_path == null)
                    continue;

                var deps_file = File.new_for_path (vapi_path.substring (0, vapi_path.length - 5) + ".deps");
                if (deps_file.query_exists()) {
                    try {
                        var dis = new DataInputStream (deps_file.read());
                        string dep;
                        var start = true;
                        while ((dep = dis.read_line (null)) != null) {
                            if (!(dep in deps)) {
                                deps.offer_head (dep);
                                if (start) {
                                    start = false;
                                    // TRANSLATORS:
                                    // There will be a list appended:
                                    // Dependencies of 'package': dep1, dep2, dep3...
                                    debug_msg (_("Dependencies of '%s': %s"), package_name, dep);
                                } else if (debug)
                                    stdout.printf (", %s", dep);
                            }
                        }
                        if (!start && debug)
                            stdout.printf ("\n");
                    } catch (IOError e) {
                        errmsg (_("Could not read line: %s\n"), e.message);
                    } catch (Error e) {
                        errmsg (_("Could not read file: %s\n"), e.message);
                    }
                }
            }

            var new_deps = new string[0];
            foreach (var dep in deps)
                if (dep in package_names)
                    skip_pkgs += dep;
                else if (!(dep in new_deps))
                    new_deps += dep;
            if (new_deps.length > 0)
                foreach (var dep in get_package_dependencies_int (context, new_deps))
                    deps.offer_head (dep);

            return deps.to_array();
        }

        /**
         * Wrap {@link CodeContext.get_packages} method.
         */
        //NOTE: "get_packages" name causes compiler error so change the name.
        public inline Vala.List<string> get_context_packages() {
            lock (context)
                return context.get_packages();
        }

        /**
         * Wrap {@link CodeContext.get_vapi_path} method.
         */
        public inline string? get_context_vapi_path (string package) {
            lock (context)
                return context.get_vapi_path (package);
        }

        public inline Vala.Map<string, Vala.Set<string>> get_defines_used() {
            return parser.used_defines;
        }
     }

    /**
     * Print debug information if {@link debug} is `true`.
     *
     * @param format Format string.
     * @param ... Arguments for format string.
     */
    private inline void debug_msg (string format, ...) {
        if (debug)
            stdout.printf (_("Guanako: ") + format.vprintf (va_list()));

    }

    public inline void warning_msg (string format, ...) {
        stdout.printf (_("Guanako: ") + _("Warning: ") + format.vprintf (va_list()));
    }

    public inline void error_msg (string format, ...) {
        stderr.printf (_("Guanako: ") + _("Error: ") + format.vprintf (va_list()));
    }

    public inline void msg (string format, ...) {
        stdout.printf (_("Guanako: ") + format.vprintf (va_list()));
    }

    public inline void errmsg (string format, ...) {
        stderr.printf (_("Guanako: ") + format.vprintf (va_list()));
    }
}

// vim: set ai ts=4 sts=4 et sw=4
