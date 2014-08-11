/*
 * guanako/stylecheck.vala
 * Copyright (C) 2013, Valama development team
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
    /**
     * Do some custom coding style checks like whitespace and bracket style.
     */
    public class StyleChecker {
        /**
         * Compatible version number of configuration file.
         */
        const string STYLE_VERSION_MIN = "0.1";

        /**
         * Associated {@link Guanako.Project}.
         */
        Guanako.Project? project = null;
        /**
         * List of checks.
         */
        public Gee.ArrayList<CheckMap?> checkmaps { get; private set; }
        /**
         * List of checks ordered by type of check.
         */
        public Gee.HashMap<CheckType, Gee.ArrayList<CheckMap?>> checklist { get; private set; }

        /**
         * List of found errors.
         */
        public Gee.ArrayList<StyleError?> errors { get; private set; }
        /**
         * Internal list of errors.
         */
        private Gee.ArrayList<StyleError?> new_errors;

        /**
         * Configuration file.
         */
        public string? stylefile { get; set; }
        /**
         * Version of configuration file.
         */
        public string stylefile_version { get; private set; default = "0"; }

        /**
         * Regex check object. Associate regex with capturing group (which is
         * the style error).
         */
        public class RegexCheck {
            public Regex regex;
            public int match_num;

            /**
             * Construct regex check object.
             *
             * @param regex {@link Regex} to check.
             * @param match_num Number of capturing group.
             */
            public RegexCheck (Regex regex, int match_num = 0) {
                this.regex = regex;
                this.match_num = match_num;
            }

            /**
             * Construct regex object from pattern.
             *
             * @param pattern Pattern to build regex from.
             * @param match_num Number of capturing group.
             */
            public RegexCheck.str (string pattern, int match_num = 0) throws GLib.RegexError {
                regex = new Regex (pattern);
                this.match_num = match_num;
            }
        }

        /**
         * Single style check object.
         */
        public struct CheckMap {
            /**
             * Ordered list of checks (with regexes).
             */
            Gee.ArrayList<RegexCheck?> checks;
            /**
             * Type of check.
             */
            CheckType type;
            /**
             * Description of check.
             */
            string description;
        }

        /**
         * Single style error object.
         */
        public class StyleError {
            /**
             * Associated check.
             */
            public CheckMap check;
            /**
             * Matching regex.
             */
            public Regex match_regex;
            /**
             * Source file.
             */
            public SourceFile file;
            /**
             * Start position.
             */
            public int start;
            /**
             * End position.
             */
            public int end;

            /**
             * Create style error object.
             *
             * @param check Check.
             * @param regex Regex.
             * @param file Source file.
             * @param start Start position.
             * @param end End position.
             */
            public StyleError (CheckMap check,
                               Regex match_regex,
                               SourceFile file,
                               int start,
                               int end) {
                this.check = check;
                this.match_regex = match_regex;
                this.file = file;
                this.start = start;
                this.end = end;
            }
        }

        /**
         * Type of checks.
         */
        public enum CheckType {
            /* Hex values would be easier to read but are to big (16^27+). */
            GLOBAL                  = 0,  // all

            // declaration
            NAMESPACE_DECLARATION   = 1 << 0,  // namespace
            // class like
            CLASS_DECLARACTION      = 1 << 1,  // class
            INTERFACE_DECLARATION   = 1 << 2,  // interface
            STRUCT_DECLARACTION     = 1 << 3,  // struct
            KLASS_DECLARATION       = 1 << 1 | 1 << 2 | 1 << 3,
            // method like
            SIGNAL_DECLARATION      = 1 << 4,  // signal
            DELEGATE_DECLARATION    = 1 << 5,  // delegate
            LAMBDA_DECLARATION      = 1 << 6,  // lambda method
            METHOD_DECLARATION      = 1 << 4 | 1 << 5 | 1 << 6,
            // global declaration
            DECLARACTION            = 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 6,

            // comparison
            COMPARISON              = 1 << 7,  // ==, !=, <, >, <=, =>

            // operators
            // assignment
            ASSIGNMENT_OPERATOR     = 1 << 8,  // =, +=, -=, /=, *=, %=, |=, &=, ^=, <<=, >>=
            ARITHMETIC_OPERATOR     = 1 << 9,  // ++, --
            ASSIGNMENT              = 1 << 8 | 1 << 9,
            // other operators
            BITWISE_OPERATOR        = 1 << 10,  // &, |, ^, <<, >>
            UNARY_OPERATOR          = 1 << 11,  // !, ~
            TERNARY_OPERATOR        = 1 << 12,  // ? :
            COALESCING_OPERATOR     = 1 << 13,  // ??
            OPERATOR                = 1 << 10 | 1 << 11 | 1 << 12 | 1 << 13,

            // control structures
            // loops
            DO_LOOP                 = 1 << 14,  // do ... while
            WHILE_LOOP              = 1 << 15,  // while ...
            FOR_LOOP                = 1 << 16,  // for
            FOREACH_LOOP            = 1 << 17,  // foreach
            LOOP                    = 1 << 14 | 1 << 15 | 1 << 16 | 1 << 17,
            // if
            IF                      = 1 << 18,  // if
            ELSE                    = 1 << 19,  // else
            IF_CONTROL              = 1 << 18 | 1 << 19,
            // switch
            SWITCH                  = 1 << 20,  // switch
            CASE                    = 1 << 21,  // case
            DEFAULT                 = 1 << 22,  // default
            SWITCH_CONTROL          = 1 << 20 | 1 << 21 | 1 << 22,
            // global control structures
            BREAK                   = 1 << 23,  // break
            CONTINUE                = 1 << 24,  // continue
            CONTROL                 = 1 << 23 | 1 << 24,

            // code attributes
            CCODE                   = 1 << 25,  // [CCode...
            OTHER_ATTRIBUTE         = 1 << 26,  // [foobar...
            ATTRIBUTE               = 1 << 25 | 1 << 26,

            // comments
            BLOCK_COMMENT           = 1 << 27,  // /* */
            LINE_COMMENT            = 1 << 28,  // //
            COMMENT                 = 1 << 27 | 1 << 28;

            /**
             * Convert string to {@link CheckType}.
             *
             * @param name CheckType as string.
             * @param result Resulting {@link CheckType} or
             *               {@link CheckType.GLOBAL} if no matching type was
             *               found.
             * @return Return `true` on success else `false`.
             */
            public static bool parse_name (string name, out CheckType result = null) {
                var ec = (EnumClass) typeof (CheckType).class_ref();
                var ev = ec.get_value_by_name ("CHECK_TYPE_" + name);
                if (ev == null) {
                    result = CheckType.GLOBAL;
                    return false;
                }

                result = (CheckType) ev.value;
                return true;
            }
        }

        /**
         * Create {@link StyleChecker} object.
         *
         * @param project {@link Guanako.Project} to associate with.
         * @param filename Name of configuration file or null.
         */
        public StyleChecker (Guanako.Project project, string? filename = null) {
            this.project = project;
            stylefile = filename;
            checkmaps = new Gee.ArrayList<CheckMap?>();
            checklist = new Gee.HashMap<CheckType,Gee.ArrayList<CheckMap?>>();
            errors = new Gee.ArrayList<StyleError?>();
        }

        /**
         * Add a new check.
         *
         * @param description Description of check.
         * @param regex {@link Regex} to check.
         * @param match_num Number of relevant capturing group.
         * @param type {@link CheckType} of check.
         */
        public void add_check (string description,
                               Regex regex,
                               int match_num = 0,
                               CheckType type = CheckType.GLOBAL) {
            var regexes = new Gee.ArrayList<RegexCheck?>();
            regexes.add (new RegexCheck (regex, match_num));
            CheckMap checkmap = {regexes, type, description};
            checkmaps.add (checkmap);
            var list = new Gee.ArrayList<CheckMap?>();
            list.add (checkmap);
            checklist.set (type, list);
        }

        /**
         * Add a new check with multiple regexes.
         *
         * @param description Description of check.
         * @param regexes List of {@link RegexCheck} objects to check.
         * @param type {@link CheckType} of check.
         */
        public void add_checks (string description,
                                Gee.ArrayList<RegexCheck?> regexes,
                                CheckType type = CheckType.GLOBAL) {
            CheckMap checkmap = {regexes, type, description};
            checkmaps.add (checkmap);
            var list = new Gee.ArrayList<CheckMap?>();
            list.add (checkmap);
            checklist.set (type, list);
        }

        /**
         * Add new check (regex) to existing check ({@link CheckMap}.
         *
         * @param regex {@link Regex} to check.
         * @param match_num Number of relevant capturing group.
         */
        public void insert_check (CheckMap checkmap,
                                  Regex regex,
                                  int match_num = 0) {
            checkmap.checks.add (new RegexCheck (regex, match_num));
        }

        /**
         * Add new checks (regexes) to existing check ({@link CheckMap}.
         *
         * @param regexes List of {@link RegexCheck} objects to check.
         */
        public void insert_checks (CheckMap checkmap,
                                   Gee.ArrayList<RegexCheck?> regexes) {
            foreach (var rcheck in regexes)
                checkmap.checks.add (rcheck);
        }

        /**
         * Remove complete check.
         *
         * @param checkmap Check.
         */
        public void delete_check (CheckMap checkmap) {
            checklist[checkmap.type].remove (checkmap);  // can now be empty
        }

        /**
         * Remove check (regex) of check ({@link CheckMap}.
         *
         * @param checkmap Check.
         * @param pos Number of regex.
         */
        public void remove_check (CheckMap checkmap, int pos) {
            checkmap.checks.remove_at (pos);  // can now be empty
        }

        /**
         * Load checks from file.
         *
         * @param filename Name of file to load checks from. If null load from
         *                 {@link stylefile}.
         */
        public void load (string? filename = null) throws GLib.IOError, GLib.RegexError {
            if (filename == null)
                filename = stylefile;
            var file = File.new_for_path (filename);
            if (!file.query_exists())
                throw new IOError.NOT_FOUND (_("File does not exist."));

            Xml.Doc* doc = Xml.Parser.parse_file (filename);
            if (doc == null) {
                delete doc;
                throw new IOError.INVALID_DATA (_("Cannot parse file."));
            }

            Xml.Node* root_node = doc->get_root_element();
            if (root_node == null || root_node->name != "stylechecks") {
                delete doc;
                throw new IOError.INVALID_DATA (_("File does not contain enough information."));
            }

            if (root_node->has_prop ("version") != null)
                stylefile_version = root_node->get_prop ("version");
            //TODO: strcmp not sufficient: 3.xx vs 15.xx
            if (strcmp (stylefile_version, STYLE_VERSION_MIN) < 0) {
                delete doc;
                throw new IOError.INVALID_DATA (_("Project file to old: %s < %s\n"),
                                                stylefile_version,
                                                STYLE_VERSION_MIN);
            }

            for (Xml.Node* i = root_node->children; i != null; i = i->next) {
                if (i->type != Xml.ElementType.ELEMENT_NODE)
                    continue;
                switch (i->name) {
                    case "check":
                        string? description = null;
                        var rchecks = new Gee.ArrayList<RegexCheck?>();
                        CheckType? type = null;
                        for (Xml.Node* p = i->children; p != null; p = p->next) {
                            if (p->type != Xml.ElementType.ELEMENT_NODE)
                                continue;
                            switch (p->name) {
                                case "description":
                                    if (description == null)
                                        description = p->get_content();
                                    else {
                                        var new_desc = p->get_content();
                                        if (description != new_desc)
                                            warning_msg (_("Skip different description: '%s' - '%s'\n"),
                                                         description, new_desc);
                                    }
                                    break;
                                case "type":
                                    if (type == null)
                                        type = (CheckType) p->get_content();
                                    else {
                                        CheckType new_type;
                                        string name = p->get_content();
                                        if (!CheckType.parse_name (name, out new_type))
                                            warning_msg (_("Unknown CheckType '%s', assume 'GLOBAL'.\n"), name);
                                        if (type != new_type)
                                            warning_msg (_("Skip different type: '%s' - '%s'\n"),
                                                           type, new_type);
                                    }
                                    break;
                                case "regexcheck":
                                    string? regex = null;
                                    int? match_num = null;
                                    for (Xml.Node* pp = p->children; pp != null; pp = pp->next) {
                                        if (pp->type != Xml.ElementType.ELEMENT_NODE)
                                            continue;
                                        switch (pp->name) {
                                            case "regex":
                                                if (regex == null)
                                                    regex = p->get_content();
                                                else {
                                                    var new_regex = p->get_content();
                                                    if (regex != new_regex)
                                                        warning_msg (_("Skip different regexes: '%s' - '%s'\n"),
                                                                     regex , new_regex);
                                                }
                                                break;
                                            case "matchgroup":
                                                if (match_num == null)
                                                    match_num = int.parse (p->get_content());
                                                else {
                                                    var new_match_num = int.parse (p->get_content());
                                                    if (match_num != new_match_num)
                                                        warning_msg (_("Skip different match groups: '%d' - '%d'\n"),
                                                                     match_num , new_match_num);
                                                }
                                                break;
                                            default:
                                                warning_msg (_("Unknown configuration file value line %hu: %s\n"), pp->line, pp->name);
                                                break;
                                        }
                                    }
                                    if (regex == null) {
                                        warning_msg (_("No regex to check.\n"));
                                        break;
                                    }
                                    if (match_num == null) {
                                        match_num = 0;
                                        // TRANSLATORS:
                                        // A "capturing group" is used to group (and possibly mark) expressions
                                        // within regular expressions for later use. Usually they are numbered
                                        // so we can access them over an index.
                                        debug_msg (_("No default capturing group ('matchgroup'). Set it to 0: %s\n"), regex);
                                    }
                                    rchecks.add (new RegexCheck.str (regex, match_num));
                                    break;
                                default:
                                    warning_msg (_("Unknown configuration file value line %hu: %s\n"), p->line, p->name);
                                    break;
                            }
                        }
                        if (description == null) {
                            description = "";
                            warning_msg (_("No description found.\n"));
                        }
                        if (type == null) {
                            type = CheckType.GLOBAL;
                            // TRANSLATORS: This is a technical information. You migth not
                            // want to translate "CheckType".
                            warning_msg (_("No CheckType found, assume 'GLOBAL'.\n"));
                        }
                        add_checks (description, rchecks, type);
                        break;
                    default:
                        warning_msg ("Unknown configuration file value line %hu: %s\n", i->line, i->name);
                        break;
                }
            }

            delete doc;
        }

        /**
         * Save checks to file.
         *
         * @param filename Name of file to save checks to. If null save to
         *                 {@link stylefile}.
         */
        public void save (string? filename = null) {
            if (filename == null)
                filename = stylefile;
            var writer = new Xml.TextWriter.filename (filename);
            writer.set_indent (true);
            writer.set_indent_string ("\t");

            writer.start_element ("stylechecks");
            writer.write_attribute ("version", stylefile_version);

            foreach (var checkmap in checkmaps) {
                writer.start_element ("check");
                writer.write_element ("description", checkmap.description);
                writer.write_element ("type", checkmap.type.to_string());
                foreach (var rcheck in checkmap.checks) {
                    writer.start_element ("regexcheck");
                    writer.write_element ("regex", rcheck.regex.get_pattern());
                    writer.write_element ("matchgroup", rcheck.match_num.to_string());
                    writer.end_element();
                }
                writer.end_element();
            }

            writer.end_element();
        }

        /**
         * Get exactly selected code region.
         *
         * @param sf {@link Vala.SourceFile} of locations.
         * @param begin {@link Vala.SourceLocation} starting point.
         * @param end {@link Vala.SourceLocation} ending point.
         * @return Return included code region. Can be a multi line string.
         */
        private string get_code_region (SourceFile sf, SourceLocation begin, SourceLocation end) {
            string region;
            if (begin.line != end.line) {
                var tmpregion = sf.get_source_line (begin.line);
                region = tmpregion.slice (begin.column, tmpregion.length) + "\n";
                for (var line = begin.line + 1; line < end.line; ++line)
                    region += sf.get_source_line (line) + "\n";
                tmpregion = sf.get_source_line (end.line);
                region += tmpregion.slice (0, end.column);
            } else
                region = sf.get_source_line (begin.line).slice(begin.column-1, end.column);
            return region;
        }

        /**
         * Get selected code region with code around.
         *
         * Region will include full lines.
         *
         * @param sf {@link Vala.SourceFile} of locations.
         * @param begin {@link Vala.SourceLocation} starting point.
         * @param end {@link Vala.SourceLocation} ending point.
         * @return Return included code region. Can be a multi line string.
         */
        private string get_code_region_line (SourceFile sf, SourceLocation begin, SourceLocation end) {
            string region = "";
            for (var line = begin.line; line < end.line; ++line)
                region += sf.get_source_line (line) + "\n";
            region += sf.get_source_line (end.line);
            return region;
        }

        /**
         * Run a single check with all checks (regexes). Add found errors to
         * internal error list. Initialize this list with {@link init_errors}
         * and swap with {@link swap_errors}.
         *
         * @param checkmap Check.
         * @param file Source file to check.
         */
        public void check (CheckMap checkmap, SourceFile file) {
            if ((checkmap.type & CheckType.DECLARACTION) == 0)
                return;
            // file.accept_children(file);
            foreach (var node in file.get_nodes()) {
                bool loopcond = true;
                switch (checkmap.type) {
                    case CheckType.GLOBAL:
                    case CheckType.NAMESPACE_DECLARATION:
                        errmsg (_("Type not implemented yet: %s\n"), checkmap.type.to_string());
                        break;
                    case CheckType.CLASS_DECLARACTION:
                        loopcond = node is Namespace || node is Class;
                        break;
                    case CheckType.INTERFACE_DECLARATION:
                    case CheckType.STRUCT_DECLARACTION:
                    case CheckType.KLASS_DECLARATION:
                    case CheckType.SIGNAL_DECLARATION:
                    case CheckType.DELEGATE_DECLARATION:
                    case CheckType.LAMBDA_DECLARATION:
                    case CheckType.METHOD_DECLARATION:
                    case CheckType.DECLARACTION:
                    case CheckType.COMPARISON:
                    case CheckType.ASSIGNMENT_OPERATOR:
                    case CheckType.ARITHMETIC_OPERATOR:
                    case CheckType.ASSIGNMENT:
                    case CheckType.BITWISE_OPERATOR:
                    case CheckType.UNARY_OPERATOR:
                    case CheckType.TERNARY_OPERATOR:
                    case CheckType.COALESCING_OPERATOR:
                    case CheckType.OPERATOR:
                    case CheckType.DO_LOOP:
                    case CheckType.WHILE_LOOP:
                    case CheckType.FOR_LOOP:
                    case CheckType.FOREACH_LOOP:
                    case CheckType.LOOP:
                    case CheckType.IF:
                    case CheckType.ELSE:
                    case CheckType.IF_CONTROL:
                    case CheckType.SWITCH:
                    case CheckType.CASE:
                    case CheckType.DEFAULT:
                    case CheckType.SWITCH_CONTROL:
                    case CheckType.BREAK:
                    case CheckType.CONTINUE:
                    case CheckType.CONTROL:
                    case CheckType.CCODE:
                    case CheckType.BLOCK_COMMENT:
                    case CheckType.LINE_COMMENT:
                    case CheckType.COMMENT:
                        errmsg (_("Type not implemented yet: %s\n"), checkmap.type.to_string());
                        break;
                    default:
                        warning_msg (_("Unknown CheckType: %s\n"), checkmap.type.to_string());
                        break;
                }
                // if (!loopcond)
                //     continue;
                stdout.printf ("node: %s\n", node.type_name);
                var exact_region = get_code_region (node.source_reference.file,
                                                    node.source_reference.begin,
                                                    node.source_reference.end);
                stdout.printf ("line:|%s|\n", exact_region);

                iter_symbol ((Symbol) node, (smb, depth) => {
                    stdout.printf ("Symbol: %s\n", smb.name);
                    exact_region = get_code_region (smb.source_reference.file,
                                                    smb.source_reference.begin,
                                                    smb.source_reference.end);
                    stdout.printf ("line:|%s|\n", exact_region);
                    return IterCallbackReturns.CONTINUE;;
                });

                continue;

                var line_region = get_code_region_line (node.source_reference.file,
                                                        node.source_reference.begin,
                                                        node.source_reference.end);
                stdout.printf ("|--|%s|--|\n", line_region);

                foreach (var rcheck in checkmap.checks) {
                    stdout.printf ("Check -- ");
                    stdout.printf ("Regex: %s\n", rcheck.regex.get_pattern());
                    MatchInfo info;
                    if (rcheck.regex.match (line_region, 0, out info)) {
                        int start;
                        int end;
                        info.fetch_pos (rcheck.match_num, out start, out end);
                        stdout.printf ("matched:|%s|\n", line_region.slice (start, end));
                        new_errors.add (new StyleError (checkmap,
                                                        rcheck.regex,
                                                        file,
                                                        start,
                                                        end));
                    }
                }
            }
        }

        /**
         * Iterate over all source files and run all checks on each.
         */
        public void check_all() {
            init_errors();
            foreach (var file in project.sourcefiles) {
                debug_msg ("\nProcessing source file: %s\n", file.filename);
                foreach (var checkmap in checkmaps)
                    check (checkmap, file);
            }
            swap_errors();
        }

        /**
         * Iterate over all checks and run all for all source files.
         */
        public void check_all_by_check() {
            init_errors();
            foreach (var checkmap in checkmaps)
                foreach (var file in project.sourcefiles) {
                    debug_msg ("\nProcessing source file: %s\n", file.filename);
                    check (checkmap, file);
                }
            swap_errors();
        }

        /**
         * Run all checks on one source file.
         *
         * @param file {@link Vala.SourceFile} to check.
         */
        public void check_all_by_file (SourceFile file) {
            init_errors();
            debug_msg ("\nProcessing source file: %s\n", file.filename);
            foreach (var checkmap in checkmaps)
                check (checkmap, file);
            swap_errors();
        }

        /**
         * Initialize internal list of errors.
         */
        public void init_errors() {
            new_errors = new Gee.ArrayList<StyleError?>();
        }

        /**
         * Swap internal errors to public list.
         *
         * @param errlist If not null swap to errlist instead of
         *                {@link errors}.
         */
        public void swap_errors (Gee.ArrayList<StyleError?>? errlist = null) {
            if (errlist != null)
                errlist = new_errors;
            else
                lock (errors)
                    errors = new_errors;
        }

        /**
         * Clear errors.
         */
        public void clear() {
            init_errors();
            lock (errors)
                swap_errors();
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
