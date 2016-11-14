
[DBus (name = "org.valama.codecontextd")]
public class DemoServer : Object {

    private int counter;

    private Vala.CodeContext context = null;

    private Guanako.Project guanako_project = null;
    private Guanako.Project.CompletionRun completion_run = null;

    public string[] get_errors_serialized() {
      return errors_serialized;
    }

    private string[] errors_serialized = new string[0];

    public void quitd() {
      Bus.unown_name (name_id);
      main_loop.quit();
    }

    public void initialize (string[] defines, string[] vapi_directories, string[] libraries, string[] source_files) {

      context = new Vala.CodeContext();

      // Use own error report supporting serialization
      var report = new Report();
      context.report = report;

      Vala.CodeContext.push (context);

      context.profile = Vala.Profile.GOBJECT;
      context.add_define ("GOBJECT");

      context.target_glib_major = 2;
      context.target_glib_minor = 38;
      context.thread = true;

      foreach (var define in defines)
        context.add_define (define);

      string[] new_vapi_dirs = vapi_directories;
      foreach (string dir in context.vapi_directories)
        new_vapi_dirs += dir;
      context.vapi_directories = new_vapi_dirs;

      string std_pkgs[2] = {"glib-2.0", "gobject-2.0"};
      foreach (string pkg in std_pkgs) {
        context.add_external_package (pkg);
      }
      foreach (var pkg in libraries)
        context.add_external_package (pkg);

      foreach (var source_path in source_files) {
        /*string content;
        FileUtils.get_contents (source_path, out content);
			  var source_file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, source_path, content, false);
			  //source_file.relative_filename = source.file.get_rel();

			  var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib", null));
			  source_file.add_using_directive (ns_ref);
			  context.root.add_using_directive (ns_ref);

        context.add_source_file (source_file);*/
        context.add_source_filename (source_path);
      }


      var parser = new Vala.Parser();
      parser.parse (context);

      context.check ();
      /*if (context_internal.report.get_errors() == 0)
        context_internal.resolver.resolve (context_internal);
      if (report_internal.get_errors() == 0)
        context_internal.analyzer.analyze (context_internal);
      if (report_internal.get_errors() == 0)
        context_internal.flow_analyzer.analyze (context_internal);*/

      Vala.CodeContext.pop(); // and release it from the libvala stack

      // Serialize compiler errors
      errors_serialized = new string[report.errlist.size];
      for (int i = 0; i < report.errlist.size; i++) {
        errors_serialized[i] = report.errlist[i].serialize();
      }


      guanako_project = new Guanako.Project(context, Config.DATA_DIR + "/share/valama/guanako/syntax");

    }

    public string[] completion_simple (string filename, int line, int col, string[] fragments) {

      var source_file = get_sourcefile_by_name (filename);
      var symbol = get_symbol_at_pos (source_file, line, col);
      stdout.printf ("At symbol " + symbol.get_full_name() + "\n");
      var current_scope = symbol.scope;

      if (fragments.length > 1) {

        Vala.Symbol match = null;
        var accessible_symbols = get_accessible_symbols (source_file, line, col);
        foreach (var accessible_symbol in accessible_symbols) {
          if (accessible_symbol.name == fragments[fragments.length-1]) {
            match = Guanako.Project.CompletionRun.get_type_of_symbol(accessible_symbol,false);
          }
        }

        if (match == null) {
          stdout.printf ("kein match!\n");
          return new string[0];
        }

        for (int i = fragments.length-2; i >= 1; i--) {
          var child_symbols = Guanako.get_child_symbols(match);
          match = null;
          foreach (var child_symbol in child_symbols) {
            if (child_symbol.name == fragments[i]) {
              match = Guanako.Project.CompletionRun.get_type_of_symbol(child_symbol,false);
              break;
            }
          }
          if (match == null) {
            stdout.printf ("kein match bei 2! (fragment: " + fragments[i] + ")\n");
            return new string[0];
          }
          //scope = match.scope;
        }

        string[] serialized_proposals = new string[0];
        foreach (var child_symbol in Guanako.get_child_symbols(match)) {
          if (child_symbol.name.has_prefix(fragments[0])) {
            var proposal = new CompletionProposal(child_symbol, fragments[0].length);
            serialized_proposals += proposal.serialize();
          }
        }
        return serialized_proposals;

      } else if (fragments.length == 1)  {

        string[] serialized_proposals = new string[0];
        
        var accessible_symbols = get_accessible_symbols (source_file, line, col);
        foreach (var accessible_symbol in accessible_symbols) {
          if (accessible_symbol.name.has_prefix(fragments[0])) {
            var proposal = new CompletionProposal(accessible_symbol, fragments[0].length);
            serialized_proposals += proposal.serialize();
          }
        }

        /*for (var scope = current_scope; scope != null; scope = scope.parent_scope) {
          foreach (var symbol_name in scope.get_symbol_table().get_keys()) {
            if (symbol_name.has_prefix(fragments[0])) {
              var child_symbol = scope.get_symbol_table()[symbol_name];
              var proposal = new CompletionProposal(child_symbol.name, child_symbol.get_full_name(), fragments[0].length);
              serialized_proposals += proposal.serialize();
            }
          }
        }*/
        return serialized_proposals;
      } else {
        return new string[0];
      }
    }

    private Vala.Symbol? lookup_symbol (string name, Vala.Scope current_scope) {
      for (var scope = current_scope; scope != null; scope = scope.parent_scope) {
        if (scope.get_symbol_table().get_keys().contains(name)) {
          return scope.get_symbol_table()[name];
        }
      }
      return null;
    }

    private Gee.TreeSet<Vala.Symbol> get_accessible_symbols (Vala.SourceFile file, int line, int col) {
        var ret = new Gee.TreeSet<Vala.Symbol>((a,b) => {
                        var name_a = ((Vala.Symbol)a).name;
                        var name_b = ((Vala.Symbol)b).name;
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
        var current_symbol = get_symbol_at_pos (file, line, col);

        if (current_symbol == null)
            current_symbol = context.root;

        foreach (Vala.UsingDirective directive in file.current_using_directives) {
            var children = Guanako.get_child_symbols (directive.namespace_symbol);
            foreach (Vala.Symbol s in children)
                ret.add(s);
        }

        for (Vala.Scope scope = current_symbol.scope; scope != null; scope = scope.parent_scope) {
            foreach (var s in scope.get_symbol_table().get_values())
                ret.add(s);
        }

        /*
         * If we are inside a subroutine, propose all previously defined
         * local variables.
         */
        if (current_symbol is Vala.Subroutine) {
            var sr = (Vala.Subroutine) current_symbol;

            Vala.Statement[] candidates = new Vala.Statement[0];
            int[] depths = new int[0];

            int last_depth = -1;
            /* Add all statements before selected one to candidates. */

            Guanako.iter_subroutine (sr, (statement, depth) => {
                if (Guanako.inside_source_ref (file, line, col, statement.source_reference)) {
                    if (depth > last_depth)
                        last_depth = depth;
                    return Guanako.IterCallbackReturns.CONTINUE;
                }
                if (Guanako.before_source_ref (file, line, col, statement.source_reference)) {
                    if (depth > last_depth)
                        last_depth = depth;
                    return Guanako.IterCallbackReturns.ABORT_TREE;
                }
                if (statement is Vala.DeclarationStatement || statement is Vala.ForeachStatement) {
                    candidates += statement;
                    depths += depth;
                }
                return Guanako.IterCallbackReturns.CONTINUE;
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
                    if (candidates[q] is Vala.ForeachStatement && depths[q] + 1 <= last_depth) {  //depth + 1, as iterator variable is only available inside the loop
                        var fst = (Vala.ForeachStatement) candidates[q];
                        if (fst.type_reference != null)
                            ret.add(new Vala.Variable (fst.type_reference, fst.variable_name));
                    }
                    if (candidates[q] is Vala.DeclarationStatement) {
                        var dsc = (Vala.DeclarationStatement) candidates[q];
                        if (dsc.declaration != null) {
                            context.resolver.visit_declaration_statement (dsc);
                            ret.add(dsc.declaration);
                        }
                        /*var defined_vars = new Vala.ArrayList<Vala.Variable>();
                        dsc.get_defined_variables(defined_vars);
                        foreach (var def_var in defined_vars)
                          ret.add(def_var;)*/
                    }
                    last_depth = depths[q];
                }
            }

        }

        return ret;
    }

    private Vala.Symbol? get_symbol_at_pos (Vala.SourceFile source_file, int line, int col) {
        Vala.Symbol ret = null;
        int last_depth = -1;
        lock (context)
            Guanako.iter_symbol (context.root,
                         (smb, depth) => {
                            if (smb.name != null) {
                                Vala.SourceReference sref = smb.source_reference;
                                if (sref == null)
                                    return Guanako.IterCallbackReturns.CONTINUE;

                                /*
                                 * If the symbol is a subroutine, check its body's source
                                 * reference.
                                 */
                                if (smb is Vala.Subroutine) {
                                    var sr = (Vala.Subroutine) smb;
                                    if (sr.body != null)
                                        sref = sr.body.source_reference;
                                }

                                /*
                                 * Check source reference, do not check its children if outside
                                 */
                                if (Guanako.inside_source_ref (source_file, line, col, sref)) {
                                    if (depth > last_depth) {  //Get symbol deepest in the tree
                                        ret = smb;
                                        last_depth = depth;
                                    }
                                } else if (smb is Vala.Subroutine)
                                    return Guanako.IterCallbackReturns.ABORT_BRANCH;

                            }
                            return Guanako.IterCallbackReturns.CONTINUE;
                         });
        return ret;
    }





    public string[] completion (string filename, int line, int col, string statement) {
      var source_file = get_sourcefile_by_name (filename);
      assert (source_file != null);

      completion_run = new Guanako.Project.CompletionRun (guanako_project);
      var guanako_proposals = completion_run.run (source_file, line, col, statement);

      // Serialize completion proposals
      var serialized_proposals = new Gee.ArrayList<string>();
      foreach (var guanako_proposal_set in guanako_proposals) {
        foreach (var guanako_proposal in guanako_proposal_set) {
          var proposal = new CompletionProposal(guanako_proposal.symbol, guanako_proposal.replace_length);
          serialized_proposals.add(proposal.serialize());
        }
      }
      return serialized_proposals.to_array();
    }

    private Vala.SourceFile? get_sourcefile_by_name (string filename) {
      foreach (var file in context.get_source_files()) {
        if (file.filename == filename)
          return file;
      }
      return null;
    }

}

[DBus (name = "org.example.DemoError")]
public errordomain DemoError
{
    SOME_ERROR
}

void on_bus_aquired (DBusConnection conn) {
    try {
        conn.register_object ("/org/valama/codecontextd", new DemoServer ());
    } catch (IOError e) {
        stderr.printf ("Could not register service\n");
    }
}

MainLoop main_loop;
uint name_id;

void main (string[] args) {
    string damon_id = args[1];
    main_loop = new MainLoop ();
    name_id = Bus.own_name (BusType.SESSION, "org.valama.codecontextd" + damon_id, BusNameOwnerFlags.NONE,
                  on_bus_aquired,
                  () => {},
                  () => stderr.printf ("Could not aquire name\n"));
    main_loop.run ();
}
