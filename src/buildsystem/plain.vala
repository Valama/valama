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
    private string[]? cmdline;

    public BuilderPlain() throws BuildError.INITIALIZATION_FAILED {
        init_dir (buildpath);
        cmdline = null;
    }

    public override string get_executable() {
        return project.project_name.casefold();
    }

    public override inline string get_name() {
        return get_name_static();
    }

    public static new string get_name_static() {
        return "Plain build system";
    }

    public override bool initialize (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED {
        exit_status = null;
        initialized = false;
        initialize_started();
        cmdline = null;

        string[] valacargs = new string[] {"valac"};
        valacargs += "--target-glib=2.32"; //TODO; Avoid hardcoding.
        valacargs += "--thread";
        valacargs += @"--output=$(get_executable())";

        foreach (var pkgname in project.guanako_project.packages)
            valacargs += @"--pkg=$pkgname";

        if (project.idemode != IdeModes.DEBUG) {
            foreach (var file in project.guanako_project.get_source_files())
                valacargs += file.filename;
        } else {
            int cnt = 0;
            foreach (var src_file_path in project.files){
                if (src_file_path.has_suffix (".vapi"))
                    continue;
                string content;
                try {
                    FileUtils.get_contents (src_file_path, out content);
                } catch (GLib.FileError e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could read file content of '%s': %s\n"),
                                                                src_file_path, e.message);
                }
                var srcfile = project.guanako_project.get_source_file_by_name (src_file_path);
                srcfile.content = content; //TODO: Find out why SourceFile.content is empty at the beginning (??)
                var tmppath = Path.build_path (Path.DIR_SEPARATOR_S,
                                               buildpath,
                                               cnt.to_string() + ".vala");
                var tmpfile = File.new_for_path (tmppath);

                try {
                    var dos = new DataOutputStream (tmpfile.replace (null,
                                                                     false,
                                                                     FileCreateFlags.REPLACE_DESTINATION));
                    dos.put_string (frankenstein.frankensteinify_sourcefile (srcfile));
                    if (cnt == 0)
                        dos.put_string (frankenstein.get_frankenstein_mainblock());
                } catch (GLib.IOError e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could not update file: %s\n"),
                                                                e.message);
                } catch (GLib.Error e) {
                    throw new BuildError.INITIALIZATION_FAILED (_("Could not open file to write: %s\n"),
                                                                e.message);
                }
                valacargs += tmppath;
                cnt++;
            }
        }

        cmdline = valacargs;

        Pid? pid;
        if (!call_cmd (cmdline, out pid)) {
            initialize_finished();
            throw new BuildError.INITIALIZATION_FAILED (_("initialization failed"));
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = Process.exit_status (status);
            Process.close_pid (intpid);
            builder_loop.quit();
        });

        builder_loop.run();
        exit_status = exit;
        initialized = true;
        initialize_finished();
        return exit_status == 0;
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
            throw new BuildError.BUILD_FAILED ("build failed");
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = Process.exit_status (status);
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
