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

namespace Units {

    public class Report : Vala.Report {
        public Gee.ArrayList<Error> errlist = new Gee.ArrayList<Error>();

        public class Error : Object {
            public Vala.SourceReference source;
            public string message;
            public EnumReportType type;

            public Error (Vala.SourceReference? source, string message, EnumReportType type) {
                this.source = source;
                this.message = message;
                this.type = type;
            }
        }

        public void reset_file (string filename) {
            var errlist_new = new Gee.ArrayList<Error>();
            foreach (var err in errlist)
                if (err.source.file.filename == filename) {
                    switch (err.type) {
                        case EnumReportType.DEPRECATED:
                        case EnumReportType.EXPERIMENTAL:
                        case EnumReportType.WARNING:
                            --warnings;
                            break;
                        case EnumReportType.ERROR:
                            --errors;
                            break;
                        case EnumReportType.NOTE:
                            break;
                        default:
                            assert_not_reached();
                    }
                } else
                    errlist_new.add (err);
            errlist = errlist_new;
        }

        protected virtual inline void show_note (Vala.SourceReference? source, string message) {}
        protected override void note (Vala.SourceReference? source, string message) {
            show_note (source, message);
            errlist.add (new Error (source, message, EnumReportType.NOTE));
        }

        protected virtual inline void show_deprecated (Vala.SourceReference? source, string message) {}
        protected override void depr (Vala.SourceReference? source, string message) {
            show_deprecated (source, message);
            ++warnings;
            errlist.add (new Error (source, message, EnumReportType.DEPRECATED));
        }

        protected virtual inline void show_experimental (Vala.SourceReference? source, string message) {}
        protected virtual inline void show_warning (Vala.SourceReference? source, string message) {}
        protected override void warn (Vala.SourceReference? source, string message) {
            EnumReportType type;
            if (message.has_suffix ("are experimental")) {
                show_experimental (source, message);
                type = EnumReportType.EXPERIMENTAL;
            } else {
                show_warning (source, message);
                type = EnumReportType.WARNING;
            }
            ++warnings;
            errlist.add (new Error (source, message, type));
        }

        protected virtual inline void show_error (Vala.SourceReference? source, string message) {}
        protected override void err (Vala.SourceReference? source, string message) {
            show_error (source, message);
            ++errors;
            errlist.add (new Error (source, message, EnumReportType.ERROR));
        }
    }
}

// vim: set ai ts=4 sts=4 et sw=4
