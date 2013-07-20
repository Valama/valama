/*
 * guanako/guanako_helpers.vala
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

namespace Guanako {
    public static inline string? get_vapi_path (string pkg, string[]? directories = null) {
        return get_file_path (pkg, ".vapi", directories);
    }

    public static inline string? get_deps_path (string pkg, string[]? directories = null) {
        return get_file_path (pkg, ".deps", directories);
    }

    private static string? get_file_path (string pkg, string ext, string[]? directories) {
        if  (directories != null)
            //TRANSLATORS: E.g.: Checking .vapi dir: /usr/share/vala/vapi
            foreach (var dir in directories) {
                debug_msg ("Checking %s dir: %s\n", ext, dir);
                var filename = Path.build_path (Path.DIR_SEPARATOR_S, dir, pkg + ext);
                if (FileUtils.test (filename, FileTest.EXISTS))
                    return filename;
            }
        foreach (var dir in get_vapi_dirs()) {
            debug_msg ("Checking %s dir: %s\n", ext, dir);
            var filename = Path.build_path (Path.DIR_SEPARATOR_S, dir, pkg + ext);
            if (FileUtils.test (filename, FileTest.EXISTS))
                return filename;
        }
        return null;
    }

    public static string[] get_vapi_dirs() {
        var dirs = new string[0];
        foreach (var dir in Environment.get_system_data_dirs())
            dirs += Path.build_path (Path.DIR_SEPARATOR_S, dir, "vala/vapi");
        foreach (var dir in Environment.get_system_data_dirs())
            dirs += Path.build_path (Path.DIR_SEPARATOR_S, dir,
                                     "vala-" + Config.VALA_VERSION,
                                     "vapi");
        return dirs;
    }

    /**
     * Get Vala packages from filenames and sort them.
     */
    public static GLib.List<string>? get_available_packages() {
        GLib.List<string> list = null;
        foreach (string path in get_vapi_dirs()) {
            if (!FileUtils.test (path, FileTest.IS_DIR))
                continue;
            debug_msg ("Checking %s dir: %s\n", ".vapi", path);
            try {
                var enumerator = File.new_for_path (path).enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo file_info;
                while ((file_info = enumerator.next_file()) != null) {
                    var filename = file_info.get_name();
                    if (filename.has_suffix (".vapi"))
                        list.insert_sorted (filename.substring (0, filename.length - 5), strcmp);
                }
            } catch (GLib.Error e) {
                stdout.printf (_("Could not update vapi files: %s\n"), e.message);
                return null;
            }
        }
        return list;
    }

     //Helper function for checking whether a given source location is inside a SourceReference
    public static bool before_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.begin.line > source_line)
            return true;
        if (reference.begin.line == source_line && reference.begin.column > source_col)
            return true;
        return false;
    }

    public static bool after_source_ref (SourceFile source_file,
                                         int source_line,
                                         int source_col,
                                         SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.end.line < source_line)
            return true;
        if (reference.end.line == source_line && reference.end.column < source_col)
            return true;
        return false;
    }

    public static bool inside_source_ref (SourceFile source_file,
                                          int source_line,
                                          int source_col,
                                          SourceReference? reference) {
        if (reference == null)
            return false;

        if (reference.file != source_file)
            return false;
        if (reference.begin.line > source_line || reference.end.line < source_line)
            return false;
        if (reference.begin.line == source_line && reference.begin.column > source_col)
            return false;
        if (reference.end.line == source_line && reference.end.column < source_col)
            return false;
        return true;
    }

    public static string symbolsig_to_string (Symbol smb, bool? fullsig = false,
                                            bool? fullname = false, string format = " ",
                                            string formatfst = "", string formatlst = "") {
        var lblstr = new StringBuilder();
        if (smb is Method) {
            var mth = (Method) smb;
            var relname = mth.get_full_name();

            if (fullsig != null && fullsig) {
                switch (mth.access) {
                    case SymbolAccessibility.INTERNAL:
                        lblstr.append ("internal ");
                        break;
                    case SymbolAccessibility.PRIVATE:
                        lblstr.append ("private ");
                        break;
                    case SymbolAccessibility.PROTECTED:
                        lblstr.append ("protected ");
                        break;
                    case SymbolAccessibility.PUBLIC:
                        lblstr.append ("public ");
                        break;
                    default:
                        stderr.printf (_("No valid %s type: %u - %s\n"),
                                 "SymbolAccessibility", mth.access,
                                 "CompletionProposal.proposal");
                        stderr.printf (_("Please report a bug!\n"));
                        break;
                }
                if (mth.binding == MemberBinding.STATIC)
                    lblstr.append ("static ");

                if (mth.is_async_callback)
                    lblstr.append ("async ");
                if (mth.is_inline)
                    lblstr.append ("inline ");

                if (mth.is_abstract)
                    lblstr.append ("abstract ");
                else if (mth.overrides)
                    lblstr.append ("override ");
                else if (mth.is_virtual)
                    lblstr.append ("virtual ");
            }

            if (mth.has_result) {
                if (!mth.return_type.value_owned)
                    lblstr.append ("unowned ");
                if (fullname == null)
                    lblstr.append (datatype_to_string (mth.return_type, relname) + " ");
                else if (fullname)
                    lblstr.append (datatype_to_string (mth.return_type, "") + " ");
                else
                    lblstr.append (datatype_to_string (mth.return_type, null) + " ");
            } else if (!(smb is CreationMethod))
                lblstr.append ("void ");

            if (fullname == null) {
                lblstr.append (mth.get_full_name() + " (" + formatfst);
                if (fullsig == null && mth.get_parameters().size > 0)
                    lblstr.append ("..");
                else
                    lblstr.append (parameters_to_string (mth.get_parameters(), relname, format));
            } else if (fullname) {
                lblstr.append (relname + " (" + formatfst);
                if (fullsig == null && mth.get_parameters().size > 0)
                    lblstr.append ("..");
                else
                    lblstr.append (parameters_to_string (mth.get_parameters(), "", format));
            } else {
                lblstr.append (mth.name + " (" + formatfst);
                if (fullsig == null && mth.get_parameters().size > 0)
                    lblstr.append ("..");
                else
                    lblstr.append (parameters_to_string (mth.get_parameters(), null, format));
            }
            lblstr.append (formatlst + ")");

            if (fullsig != null && fullsig) {
                foreach (var precond in mth.get_preconditions())
                    lblstr.append ("\nrequires (" + expression_to_string (precond) + ")");
                foreach (var postcond in mth.get_postconditions())
                    lblstr.append ("\nensures (" + expression_to_string (postcond) + ")");
            }
            //TODO: deprecated and experimental
        } else if (smb is Class) {
            //TODO: base types
            if (fullsig != null) {
                var mth = ((Class) smb).default_construction_method;
                if (mth != null) {
                    var relname = mth.get_full_name();

                    if (fullname == null) {
                        lblstr.append (smb.get_full_name() + " (" + formatfst);
                        lblstr.append (parameters_to_string (mth.get_parameters(), relname, format));
                    } else if (fullname) {
                        lblstr.append (smb.get_full_name() + " (" + formatfst);
                        lblstr.append (parameters_to_string (mth.get_parameters(), "", format));
                    } else {
                        lblstr.append (smb.name + " (" + formatfst);
                        lblstr.append (parameters_to_string (mth.get_parameters(), null, format));
                    }
                    lblstr.append (formatlst + ")");
                } else
                    lblstr.append (smb.name);
            } else
                lblstr.append (smb.name);
        } else {
            //TODO: All other possible types.
            if (fullname == null || fullname)
                lblstr.append (smb.get_full_name());
            else
                lblstr.append (smb.name);
        }
        return lblstr.str;
    }

    private static string get_symbol_rel_name (Symbol smb, string? relsmb) {
        if (relsmb == null)
            return smb.name;
        else if (relsmb == "")
            return smb.get_full_name();
        else {
            var s = smb.get_full_name();
            if (s.has_prefix (relsmb)) {
                if (s[relsmb.length + 1] == '.')
                    return s[relsmb.length:s.length];
                else
                    return s[relsmb.length + 1:s.length];
            } else
                return s;
        }
    }

    private static string parameters_to_string (Vala.List<Vala.Parameter>? prms, string? relname, string format) {
        var lblstr = new StringBuilder();
        for (int q = 0; q < prms.size; q++) {
            if (prms[q].ellipsis) {
                lblstr.append ("...");
                break;
            }

            switch (prms[q].direction) {
                case ParameterDirection.OUT:
                    lblstr.append ("out ");
                    break;
                case ParameterDirection.REF:
                    lblstr.append ("ref ");
                    break;
                default:
                    // if (prms[q].variable_type.is_weak())
                    //     lblstr.append ("weak ");
                    if (prms[q].variable_type.value_owned)  //TODO: possible?
                        lblstr.append ("owned ");
                    break;
            }

            lblstr.append (datatype_to_string (prms[q].variable_type, relname));
            lblstr.append (" " + get_symbol_rel_name (prms[q], relname));

            if (prms[q].initializer != null)
                lblstr.append (" = " + expression_to_string (prms[q].initializer));

            if (q < prms.size - 1)
                lblstr.append ("," + format);

        }
        return lblstr.str;
    }

    private static string expression_to_string (Expression e) {
        if (e is Literal)
            return e.to_string();
        else if (e is MemberAccess)
            return "%s".printf (((MemberAccess) e).member_name);
        else if (e is BinaryExpression) {
            var be = (BinaryExpression) e;
            return "%s %s %s".printf (expression_to_string (be.left),
                                      binary_operator_to_string (be.operator),
                                      expression_to_string (be.right));
        } else if (e is UnaryExpression) {
            var ue = (UnaryExpression) e;
            return "%s%s".printf (unary_operator_to_string (ue.operator),
                                  expression_to_string (ue.inner));
        } else if (e is ArrayCreationExpression) {
            var ace = (ArrayCreationExpression) e;
            var str = datatype_to_string (ace.element_type, null);
            if (ace.initializer_list != null) {
                var initializer_list = ace.initializer_list.get_initializers();
                if (initializer_list.size > 0) {
                    var lblstr = new StringBuilder ("{" + expression_to_string (initializer_list[0]));
                    for (int i = 1; i < ace.initializer_list.size; ++i)
                        lblstr.append (", " + expression_to_string (initializer_list[i]));
                    lblstr.append ("}");
                    return lblstr.str;
                }
            }
            if (ace.rank == 1 && str == "string")
                return "{}";
            else
                return "new %s[%d]".printf (str, ace.rank-1);
        } else {
            stderr.printf (_("Unknown expression: %s\n"), e.type_name);
            stderr.printf (_("Please report a bug!\n"));
            return "";
        }
    }

    private static string binary_operator_to_string (BinaryOperator op) {
        switch (op) {
            case BinaryOperator.NONE:
                return "";
            case BinaryOperator.PLUS:
                return "+";
            case BinaryOperator.MINUS:
                return "-";
            case BinaryOperator.MUL:
                return "*";
            case BinaryOperator.DIV:
                return "/";
            case BinaryOperator.MOD:
                return "%";
            case BinaryOperator.SHIFT_LEFT:
                return "<<";
            case BinaryOperator.SHIFT_RIGHT:
                return ">>";
            case BinaryOperator.LESS_THAN:
                return "<";
            case BinaryOperator.GREATER_THAN:
                return ">";
            case BinaryOperator.LESS_THAN_OR_EQUAL:
                return "<=";
            case BinaryOperator.GREATER_THAN_OR_EQUAL:
                return ">=";
            case BinaryOperator.EQUALITY:
                return "==";
            case BinaryOperator.INEQUALITY:
                return "!=";
            case BinaryOperator.BITWISE_AND:
                return "&";
            case BinaryOperator.BITWISE_OR:
                return "|";
            case BinaryOperator.BITWISE_XOR:
                return "^";
            case BinaryOperator.AND:
                return "&&";
            case BinaryOperator.OR:
                return "||";
            case BinaryOperator.IN:
                return "in";
            case BinaryOperator.COALESCE:
                return "??";
            default:
                EnumClass cl = (EnumClass) typeof (BinaryOperator).class_ref ();
                return cl.get_value (op).value_nick;
        }
    }

    private static string unary_operator_to_string (UnaryOperator op) {
        switch (op) {
            case UnaryOperator.NONE:
                return "";
            case UnaryOperator.PLUS:
                return "+";
            case UnaryOperator.MINUS:
                return "-";
            case UnaryOperator.LOGICAL_NEGATION:
                return "^";
            case UnaryOperator.BITWISE_COMPLEMENT:
                return "~";
            case UnaryOperator.INCREMENT:
                return "++";
            case UnaryOperator.DECREMENT:
                return "--";
            case UnaryOperator.REF:
                return "ref";
            case UnaryOperator.OUT:
                return "out";
            default:
                EnumClass cl = (EnumClass) typeof (UnaryOperator).class_ref ();
                return cl.get_value (op).value_nick;
        }
    }

    private static string datatype_to_string (DataType? vt, string? relname) {
        var lblstr = new StringBuilder();
        var shownull = true;
        if (vt.is_array()) {
            var arr = (vt as ArrayType).element_type;
            if (arr is GenericType)
                lblstr.append (((GenericType) arr).to_qualified_string());
            else if (arr is PointerType) {
                uint i = 0;
                lblstr.append (pointertype_to_string ((PointerType) arr, relname, ref i));
                lblstr.append (type_arguments_to_string (vt.get_type_arguments(), relname));
                while (i-- != 0)
                    lblstr.append ("*");
            } else
                lblstr.append (get_symbol_rel_name (arr.data_type, relname));
            lblstr.append (type_arguments_to_string (vt.get_type_arguments(), relname));
            if (arr.nullable)
                lblstr.append ("?");
            lblstr.append ("[]");
        } else {
            uint i = 0;
            if (vt.data_type != null)
                lblstr.append (get_symbol_rel_name (vt.data_type, relname));
            else if (vt is DelegateType)
                lblstr.append (get_symbol_rel_name (((DelegateType) vt).delegate_symbol, relname));
            else if (vt is PointerType) {
                lblstr.append (pointertype_to_string ((PointerType) vt, relname, ref i));
                shownull = false;
            } else if (vt is GenericType) {
                lblstr.append (((GenericType) vt).to_qualified_string());
                shownull = false;
            } else if (vt is Vala.ErrorType) {
                var et = (Vala.ErrorType) vt;
                if (et.error_domain != null)
                    lblstr.append (get_symbol_rel_name (et.error_domain, relname));
                else {
                    if (relname == null)
                        lblstr.append ("Error");
                    else
                        lblstr.append ("GLib.Error");
                }
            } else {  //TODO: Can this happen?
                stderr.printf (_("Unknown type: %s\n"), vt.to_qualified_string());
                stderr.printf (_("Please report a bug!\n"));
                lblstr.append ("UNKOWN");
            }

            lblstr.append (type_arguments_to_string (vt.get_type_arguments(), relname));

            while (i-- != 0)
                lblstr.append ("*");
        }
        if (shownull && vt.nullable)
            lblstr.append ("?");
        return lblstr.str;
    }

    private static string pointertype_to_string (PointerType vt, string? relname, ref uint i) {
        var lblstr = new StringBuilder();
        DataType vt_tmp = vt;
        while (true) {
            ++i;
            vt_tmp = (vt_tmp as PointerType).base_type;
            if (vt_tmp is VoidType) {
                lblstr.append ("void");
                break;
            } else if (vt_tmp.data_type != null) {
                lblstr.append (get_symbol_rel_name (vt_tmp.data_type, relname));
                break;
            } else if (vt_tmp is DelegateType) {
                lblstr.append (get_symbol_rel_name (((DelegateType) vt_tmp).delegate_symbol, relname));
                break;
            } else if (vt_tmp is GenericType) {
                lblstr.append (((GenericType) vt_tmp).to_qualified_string());
                break;
            }
        }
        return lblstr.str;
    }

    private static string type_arguments_to_string (Vala.List<DataType> typeargs, string? relname) {
        var lblstr = new StringBuilder();
        if (typeargs.size > 0) {
            lblstr.append ("<");
            for (int j = 0; j < typeargs.size - 1; ++j) {
                lblstr.append (datatype_to_string (typeargs[j], relname));
                lblstr.append (", ");
            }
            lblstr.append (datatype_to_string (typeargs[typeargs.size - 1], relname));
            lblstr.append (">");
        }
        return lblstr.str;
    }

    public static string symboltype_to_string (Symbol smb) {
        //NOTE: Order of checks should represent frequency of occurrence.
        if (smb is Subroutine) {
            if (smb is Method) {
                if (smb is CreationMethod)
                    return _("Creation method");
                if (smb is DynamicMethod)
                    return _("Dynamic method");
                if (smb is ArrayMoveMethod)
                    return _("Array move method");
                if (smb is ArrayResizeMethod)
                    return _("Array resize method");
                return _("Method");
            }
            if (smb is Constructor)
                return _("Constructor");
            if (smb is Destructor)
                return _("Destructor");
            if (smb is PropertyAccessor)
                return _("Property accessor");
            return _("Subroutine");
        }

        if (smb is TypeSymbol) {
            if (smb is ObjectTypeSymbol) {
                if (smb is Class)
                    return _("Class");
                if (smb is Enum)
                    return _("Enum");
                if (smb is Interface)
                    return _("Interface");
                if (smb is Delegate)
                    return _("Delegate");
                if (smb is ErrorCode)
                    return _("Error code");
                if (smb is ErrorDomain)
                    return _("Error domain");
                return _("Object type symbol");
            }
            if (smb is Struct)
                return _("Struct");
            return _("Type symbol");
        }

        if (smb is Variable) {
            if (smb is LocalVariable)
                return _("Local variable");
            if (smb is Vala.Parameter)
                return _("Parameter");
            if (smb is Field)
                return _("Field");
            if (smb is ArrayLengthField)
                return _("Array length field");
            return _("Variable");
        }

        if (smb is Block) {
            if (smb is ForeachStatement)
                return _("Foreach statement");
            if (smb is SwitchSection)
                return _("Switch section");
            return _("Block");
        }

        if (smb is Constant) {
            if (smb is Vala.EnumValue)
                return _("Enum value");
            return _("Constant");
        }

        if (smb is Namespace)
            return _("Namespace");

        if (smb is Property) {
            if (smb is DynamicProperty)
                return _("Dynamic property");
            return _("Property");
        }

        if (smb is Vala.Signal) {
            if (smb is DynamicSignal)
                return _("Dynamic signal");
            return _("Signal");
        }

        if (smb is TypeParameter)
            return _("Type parameter");

        if (smb is UnresolvedSymbol)
            return _("Unresolved symbol");

        stderr.printf (_("Could not get type name of: %s\n"), smb.name);
        return "";
    }
}

// vim: set ai ts=4 sts=4 et sw=4
