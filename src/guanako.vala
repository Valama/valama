using GLib;
using Vala;


namespace Guanako{

     public class project {

         CodeContext context;

         public project(){
            context = new CodeContext ();
            CodeContext.push(context);
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
            Vala.Parser parser = new Vala.Parser();
            parser.parse(context);
             var res = new SymbolResolver();
             res.resolve(context);
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
            } else if (splt[1] == "="){
                var accessible = get_accessible_symbols(file, line, col);

                Symbol type = null;
                if (splt.length >= 3)
                    type = resolve_symbol(splt[2], accessible);

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
            
            int depth = -1;
            int start_id = 0;
            do {
                for (int q = 0; q < txt.length; q++){
                    if (txt[q] == (char)("(")){
                        if (depth < 1)
                            start_id = q;
                        depth ++;
                    }else if (txt[q] == (char)("(")){
                        depth --;
                        if (depth == 0){
                            txt = txt.substring(start_id, q - start_id);
                            break;
                        }
                    }
                }
            } while (depth > -1);
            
            int last_occurrence = int.max(-1, txt.last_index_of("."));
            last_occurrence = int.max(last_occurrence, txt.last_index_of(","));
            if (last_occurrence >= 0)
                txt = txt.substring(last_occurrence + 1);

            string[] splt = txt.split(".");
            if (splt.length == 1)
                return null;

            if (candidates == null){
                internal_candidates = get_child_symbols(context.root);
                /*internal_candidates = new Symbol[0];
                iter_symbol (context.root, (iter, depth)=>{
                    if (depth == 1){
                        internal_candidates += iter;
                        return iter_callback_returns.abort_branch;
                    }
                    return iter_callback_returns.continue;
                }, 0);*/
            }


             foreach (Symbol smb in internal_candidates){
                 if (smb.name == splt[0]){
                    Symbol type = null;
                    if (smb is Class || smb is Namespace)
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

         Symbol[] get_child_symbols(Symbol parent){
             Symbol[] ret = new Symbol[0];
            iter_symbol(parent, (s, depth)=>{
                ret += s;
                return iter_callback_returns.abort_branch;
             });
             return ret;
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
            if (current_symbol == null)
                return ret;

            // Propose all accessible non-local namespaces, classes etc
            iter_symbol (context.root, (iter, depth)=>{
                if (current_symbol.is_accessible(iter)){
                    ret += iter;

                    //TODO: Abort if inside other namespace

                    /*if (iter is Namespace){
                        if (!namespace_in_using_directives(file, iter))
                            return iter_callback_returns.abort_branch;
                    }*/
                }
                return iter_callback_returns.continue;
            }, 0);

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
                    if (statement is DeclarationStatement){
                        candidates += statement;
                        depths += depth;
                    }
                    return iter_callback_returns.continue;
                });

                //Return all candidates with a lower or equal depth
                for (int q = candidates.length - 1; q >= 0; q--){
                    if (depths[q] <= last_depth || last_depth == -1){
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

    //Generic callback for iteration functions
    public delegate iter_callback_returns iter_callback(Symbol symbol, int depth);
    public enum iter_callback_returns{
        continue = 1,
        abort_branch,
        abort_tree
    }

     //Iterate through a symbol and its children
    public static bool iter_symbol(Symbol smb, iter_callback callback, int depth = 0){

        if (depth > 0){
            var ret = callback(smb, depth);
            if (ret == iter_callback_returns.abort_branch)
                return true;
            else if (ret == iter_callback_returns.abort_tree)
                return false;
        }

        if (smb is Namespace){
            var cv = (Namespace)smb;
            var ch = cv.get_namespaces();
            foreach (Symbol s in ch){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var mth = cv.get_methods();
            foreach (Symbol s in mth){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var cls = cv.get_classes();
            foreach (Symbol s in cls){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
        }
        if (smb is Class){
            var cv = (Class)smb;
            var mth = cv.get_methods();
            foreach (Symbol s in mth){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var cls = cv.get_classes();
            foreach (Symbol s in cls){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var cst = cv.get_constants();
            foreach (Symbol s in cst){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var fld = cv.get_fields();
            foreach (Symbol s in fld){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
        }
        if (smb is Struct){
            var cv = (Struct)smb;
            var mth = cv.get_methods();
            foreach (Symbol s in mth){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var cst = cv.get_constants();
            foreach (Symbol s in cst){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var fld = cv.get_fields();
            foreach (Symbol s in fld){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
            var prp = cv.get_properties();
            foreach (Symbol s in prp){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
        }
        if (smb is ObjectTypeSymbol){
            var cv = (ObjectTypeSymbol)smb;
            var prp = cv.get_properties();
            foreach (Symbol s in prp){
                if (!iter_symbol(s, callback, depth + 1))
                    return false;
            }
        }
        return true;
    }


    public delegate iter_callback_returns iter_statement_callback(Statement statement, int depth);

    //Iterate through a subroutine's body's statements
    public static void iter_subroutine(Subroutine subroutine, iter_statement_callback callback){
        var statements = subroutine.body.get_statements();
        foreach (Statement st in statements)
            iter_statement(st, callback, 0);
    }
    //Iterate through a statement
    public static bool iter_statement(Statement statement, iter_statement_callback callback, int depth){
        var ret = callback(statement, depth);
        if (ret == iter_callback_returns.abort_branch)
            return true;
        else if (ret == iter_callback_returns.abort_tree)
            return false;

        if (statement is Block){
            var st = (Block)statement;
            foreach (Statement ch in st.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is Loop){
            var st = (Loop)statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is ForStatement){
            var st = (ForStatement)statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is ForeachStatement){
            var st = (ForeachStatement)statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is DoStatement){
            var st = (DoStatement)statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is WhileStatement){
            var st = (WhileStatement)statement;
            foreach (Statement ch in st.body.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
        }
        if (statement is IfStatement){
            var st = (IfStatement)statement;
            foreach (Statement ch in st.true_statement.get_statements()){
                if (!iter_statement(ch, callback, depth + 1))
                    return false;
            }
            if (st.false_statement != null)
                foreach (Statement ch in st.false_statement.get_statements()){
                    if (!iter_statement(ch, callback, depth + 1))
                        return false;
                }
        }
        if (statement is LockStatement){
            var st = (LockStatement)statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements()){
                    if (!iter_statement(ch, callback, depth + 1))
                        return false;
                }
        }
        if (statement is TryStatement){
            var st = (TryStatement)statement;
            if (st.body != null)
                foreach (Statement ch in st.body.get_statements()){
                    if (!iter_statement(ch, callback, depth + 1))
                        return false;
                }
        }

        return true;
    }

}

