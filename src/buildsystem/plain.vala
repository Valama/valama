/*
 * src/buildsystem/plain.vala
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

public class BuilderPlain : BuildSystem {
    private string[]? cmdline = null;

    public override string get_executable() {
        return project.project_name.casefold();
    }

    public override inline string get_name() {
        return "Plain build system";
    }

    public override inline string get_name_id() {
        return "valama";
    }

    public override bool check_buildsystem_file (string filename) {
        return false;
    }

    public override bool initialize (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED {
        exit_status = null;
        initialized = false;
        if (!preparate())
            return false;
        initialize_started();
        cmdline = null;

        string[] valacargs = new string[] {"valac"};
        string? target_glib_version;
        if (!package_exists ("glib-2.0", out target_glib_version)) {
            //TRANSLATORS: E.g.: No `glib-2.0' package found.
            build_output (_("No '%s' package found.\n").printf ("glib-2.0"));
            return false;
        }
        valacargs += @"--target-glib=$(target_glib_version)";
        valacargs += "--thread";
        valacargs += @"--output=$(get_executable())";

        foreach (var pkg in project.packages.values) {
            build_output (_("Add package: %s\n").printf (pkg.name));
            if (pkg.custom_vapi == null)
                valacargs += @"--pkg=$(pkg.name)";
            else {
                valacargs += project.get_absolute_path (pkg.custom_vapi);
                string? pkgflags;
                if (package_flags (pkg.name, out pkgflags))
                    try {
                        string[] pkgflags_args;
                        Shell.parse_argv (pkgflags, out pkgflags_args);
                        foreach (var ccpart in pkgflags_args)
                            valacargs += @"--Xcc=$ccpart";
                    } catch (GLib.ShellError e) {
                        warning_msg (_("Could not parse package flags '%s': %s\n"),
                                     pkgflags, e.message);
                    }
            }
        }

        if (project.idemode != IdeModes.DEBUG) {
            foreach (var file in project.guanako_project.get_source_files())
                valacargs += file.filename;
        } else {
            var mainblock = false;
            foreach (var src_file_path in project.files){
                if (src_file_path.has_suffix (".vapi")) {
                    valacargs += src_file_path;
                    continue;
                }

                string content;
                try {
                    FileUtils.get_contents (src_file_path, out content);
                } catch (GLib.FileError e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could not read file content of '%s': %s\n"),
                                                                src_file_path, e.message);
                }
                var srcfile = project.guanako_project.get_source_file_by_name (src_file_path);
                srcfile.content = content; //TODO: Find out why SourceFile.content is empty at the beginning (??)
                var fname = project.get_relative_path (src_file_path);
                var tmppath = Path.build_path (Path.DIR_SEPARATOR_S,
                                               buildpath,
                                               fname.replace (Path.DIR_SEPARATOR_S, "=+"));
                var tmpfile = File.new_for_path (tmppath);

                try {
                    build_output (_("Prepare file for FrankenStein: %s\n").printf (fname));
                    var dos = new DataOutputStream (tmpfile.replace (null,
                                                                     false,
                                                                     FileCreateFlags.REPLACE_DESTINATION));
                    dos.put_string (frankenstein.frankensteinify_sourcefile (srcfile));
                    if (!mainblock) {
                        dos.put_string (frankenstein.frankenstein_mainblock);
                        mainblock = true;
                    }
                } catch (GLib.IOError e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could not update file: %s\n"),
                                                                e.message);
                } catch (GLib.Error e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could not open file writable: %s\n"),
                                                                e.message);
                }
                valacargs += tmppath;
            }
        }

        foreach (var define in project.defines)
            valacargs += @"--define=$define";

        cmdline = valacargs;

        exit_status = 0;
        initialized = true;
        initialize_finished();
        return true;
    }

    public override bool build (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED,
                                               BuildError.CONFIGURATION_FAILED,
                                               BuildError.BUILD_FAILED {
        exit_status = null;
        if (!configured && !configure (out exit_status))
            return false;

        exit_status = null;
        built = false;
        build_started();

        Pid? pid;
        if (!call_cmd (cmdline, out pid)) {
            build_finished();
            throw new BuildError.BUILD_FAILED ("build command failed");
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = get_exit (status);
            Process.close_pid (intpid);
            builder_loop.quit();
        });

        builder_loop.run();
        exit_status = exit;
        built = true;
        build_finished();
        return exit_status == 0;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
