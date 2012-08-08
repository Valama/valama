using GLib;
using Vala;


namespace Guanako{

     public class project {

        CodeContext context;
        SymbolResolver sym_resolver;
        Vala.Parser parser;
        Vala.SemanticAnalyzer analyzer;
        
        public project(){
            context = new CodeContext ();
            sym_resolver = new SymbolResolver();
            parser = new Vala.Parser();
            analyzer = new Vala.SemanticAnalyzer ();
            
            context.profile = Profile.GOBJECT;
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
        /*public void add_source_file_from_path(string path){
            var source_file = new SourceFile (context, SourceFileType.SOURCE, path);
            context.add_source_file (source_file);
        }*/
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
            sym_resolver.resolve(context);
            //analyzer.analyze(context);
            CodeContext.pop();
        }

        public Symbol[] propose_symbols(SourceFile file, int line, int col, string written){
            Symbol[] ret = new Symbol[0];

            string[] splt = written.strip().split(" ");

            if (splt[0] == "using"){

                Symbol iterate = resolve_symbol(splt[1]);
                if (iterate == null)
                    iterate = context.root;

                iter_symbol(iterate, (s, depth)=>{
                    if (s is Namespace){
                        ret += s;
                        return iter_callback_returns.abort_branch;
                    }
                    return iter_callback_returns.continue;
                });

            } else if (splt.length < 2){

                var accessible = get_accessible_symbols(file, line, col);

                var type = resolve_symbol(written.strip(), accessible);

                if (type == null){
                    ret = accessible;
                }else{
                    ret = get_child_symbols(type);
                }
            } else if (splt[splt.length - 1] == "new"){
                var accessible = get_accessible_symbols(file, line, col);
                foreach (Symbol c in accessible)
                    if (c is Namespace || c is Class)
                        ret += c;
            } else if (splt[splt.length - 2] == "new"){
                var accessible = get_accessible_symbols(file, line, col);
                Symbol type = resolve_symbol(splt[splt.length - 1], accessible);
                
                Symbol[] candidates = accessible;
                if (type == null)
                    candidates = accessible;
                else
                    candidates = get_child_symbols(type);
                
                foreach (Symbol c in candidates){
                    if (c is Namespace || c is Class || c is CreationMethod)
                        ret += c;
                }
            } else if (splt[splt.length - 1] == "="){
                ret = get_accessible_symbols(file, line, col);
            } else if (splt[splt.length - 2] == "="){
                var accessible = get_accessible_symbols(file, line, col);
                Symbol type = resolve_symbol(splt[splt.length - 1], accessible);
                if (type == null){
                    ret = accessible;
                }else{
                    ret = get_child_symbols(type);
                }
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
                    }else if (txt[q].to_string() == ")"){
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
            if (splt.length == 1)
                return null;

            if (candidates == null){
                internal_candidates = get_child_symbols(context.root);
            }


             foreach (Symbol smb in internal_candidates){
                 if (smb.name == splt[0]){
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
                    
                    if (splt.length <= 2)
                        return type;
                    else
                        return resolve_symbol(txt.substring(splt[0].length + 1), get_child_symbols(type));
                 }
             }
             return null;
         }


         bool namespace_in_using_directives(SourceFile file, Symbol nmspace){
             foreach (UsingDirective directive in file.current_using_directives){
                 if (directive.namespace_symbol == nmspace)
                     return true;
             }
             return false;
         }

         public Symbol[] get_accessible_symbols(SourceFile file, int line, int col){
            Symbol [] ret = new Symbol[0];
            var current_symbol = get_symbol_at_pos(file, line, col);
            if (current_symbol == null){
                return ret;
            }

            // Propose all accessible non-local namespaces, classes etc
            iter_symbol (context.root, (iter, depth)=>{
                if (current_symbol.is_accessible(iter)){
                    ret += iter;
                }

                if (iter is Namespace)
                    if (namespace_in_using_directives(file, iter))
                        return iter_callback_returns.continue;
                return iter_callback_returns.abort_branch;
            });
            var current_namespace = get_parent_namespace(current_symbol);
            if (current_namespace != null){
                iter_symbol (current_namespace, (iter, depth)=>{
                    if (current_symbol.is_accessible(iter)){
                        ret += iter;
                    }
                    return iter_callback_returns.abort_branch;
                });
            }
            if (current_symbol.parent_symbol != null){
                iter_symbol (current_symbol.parent_symbol, (iter, depth)=>{
                    if (current_symbol.is_accessible(iter)){
                        ret += iter;
                    }
                    return iter_callback_returns.abort_branch;
                });
            }

            //If we are inside a method, propose all parameters
            if (current_symbol is Method){
                var mth = (Method)current_symbol;
                foreach (Vala.Parameter param in mth.get_parameters()){
                    ret += param;
                }
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
                        if (sr.body != null){
                            if (inside_source_ref(source_file, line, col, sr.body.source_reference)){
                                if (depth > last_depth){//Get symbol deepest in the tree
                                    ret = smb;
                                    last_depth = depth;
                                }
                            }
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
                            /* we need to remove it from the scope*/
                            sym.owner.remove(sym.name);
                        if (context.entry_point == sym)
                            context.entry_point = null;
                    }
                }
                file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
                file.add_using_directive (ns_ref);
                context.root.add_using_directive (ns_ref);

                //report.clear_error_indicators ();


                /* visit_source_file checks for the file extension */
                parser.visit_source_file (file);

                sym_resolver.resolve (context);
                //analyzer.visit_source_file (file);

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

