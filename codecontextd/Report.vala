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


public class Report : Vala.Report {
    public Gee.ArrayList<CompilerError> errlist = new Gee.ArrayList<CompilerError>();

    public void reset_file (string filename) {
        var errlist_new = new Gee.ArrayList<CompilerError>();
        foreach (var err in errlist)
            if (err.source.file == filename) {
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

    protected override void note (Vala.SourceReference? source, string message) {
        errlist.add (new CompilerError (source, message, EnumReportType.NOTE));
    }

    protected override void depr (Vala.SourceReference? source, string message) {
        ++warnings;
        errlist.add (new CompilerError (source, message, EnumReportType.DEPRECATED));
    }

    protected override void warn (Vala.SourceReference? source, string message) {
        EnumReportType type;
        if (message.has_suffix ("are experimental")) {
            type = EnumReportType.EXPERIMENTAL;
        } else {
            type = EnumReportType.WARNING;
        }
        ++warnings;
        errlist.add (new CompilerError (source, message, type));
    }

    protected override void err (Vala.SourceReference? source, string message) {
        ++errors;
        errlist.add (new CompilerError (source, message, EnumReportType.ERROR));
    }
}

// vim: set ai ts=4 sts=4 et sw=4
