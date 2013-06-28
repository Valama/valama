/*
 * guanako/reporter.vala
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
    [Flags]
    public enum ReportType {
        ERROR,
        WARNING,
        DEPRECATED,
        EXPERIMENTAL,
        NOTE;

        public const ReportType ALL = ERROR | WARNING | DEPRECATED | EXPERIMENTAL | NOTE;

        public string? to_string() {
            switch (this) {
                case ERROR:
                    return _("Error");
                case WARNING:
                    return _("Warning");
                case DEPRECATED:
                    return _("Deprecated");
                case EXPERIMENTAL:
                    return _("Experimental");
                case NOTE:
                    return _("Note");
                default:
                    assert_not_reached();
            }
        }
    }

    public class Reporter : Report {
        public virtual Gee.ArrayList<Error> errlist { get; protected set; }
        private bool general_error = false;

        public class Error : Object {
            public SourceReference source;
            public string message;
            public ReportType type;

            public Error (SourceReference source, string message, ReportType type) {
                this.source = source;
                this.message = message;
                this.type = type;
            }
        }

        construct {
            errlist = new Gee.ArrayList<Error>();
            errors = 0;
            warnings = 0;
        }

        public void reset_file (string filename) {
            var errlist_new = new Gee.ArrayList<Error>();;
            foreach (var err in errlist)
                if (err.source.file.filename == filename) {
                    switch (err.type) {
                        case ReportType.DEPRECATED:
                        case ReportType.EXPERIMENTAL:
                        case ReportType.WARNING:
                            --warnings;
                            break;
                        case ReportType.ERROR:
                            --errors;
                            break;
                        case ReportType.NOTE:
                            break;
                        default:
                            assert_not_reached();
                    }
                } else
                    errlist_new.add (err);
            errlist = errlist_new;
        }

        protected virtual inline void show_note (SourceReference? source, string message) {}
        protected override void note (SourceReference? source, string message) {
            show_note (source, message);
            if (source == null)
                return;
            errlist.add (new Error (source, message, ReportType.NOTE));
        }

        protected virtual inline void show_deprecated (SourceReference? source, string message) {}
        protected override void depr (SourceReference? source, string message) {
            show_deprecated (source, message);
            if (source == null)
                return;
            ++warnings;
            errlist.add (new Error (source, message, ReportType.DEPRECATED));
        }

        protected virtual inline void show_experimental (SourceReference? source, string message) {}
        protected virtual inline void show_warning (SourceReference? source, string message) {}
        protected override void warn (SourceReference? source, string message) {
            ReportType type;
            if (message.has_suffix ("are experimental")) {
                show_experimental (source, message);
                type = ReportType.EXPERIMENTAL;
            } else {
                show_warning (source, message);
                type = ReportType.WARNING;
            }
            if (source == null)
                return;
            ++warnings;
            errlist.add (new Error (source, message, type));
        }

        protected virtual inline void show_error (SourceReference? source, string message) {}
        protected override void err (SourceReference? source, string message) {
            show_error (source, message);
            if (source == null) {
                general_error = true;
                return;
            }
            ++errors;
            errlist.add (new Error (source, message, ReportType.ERROR));
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
