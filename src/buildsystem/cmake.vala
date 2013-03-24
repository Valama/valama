/*
 * src/buildsystem/cmake.vala
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

public class BuilderCMake : BuildSystem {
    string projectinfo;

    public BuilderCMake() throws BuildError.INITIALIZATION_FAILED {
        init_dir (buildpath);
        projectinfo = Path.build_path (Path.DIR_SEPARATOR_S,
                                       project.project_path,
                                       "cmake",
                                       "project.cmake");
        init_dir (Path.get_dirname (projectinfo));
    }

    public override string get_executable() {
        return project.project_name.down();
    }

    public override inline string get_name() {
        return get_name_static();
    }

    public static new string get_name_static() {
        return "CMake";
    }

    public override bool initialize (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED {
        exit_status = null;
        initialized = false;
        initialize_started();

        var strb_pkgs = new StringBuilder ("set(required_pkgs\n");
        foreach (var pkgmap in get_pkgmaps().values)
            strb_pkgs.append (@"\"$pkgmap\"\n");
        strb_pkgs.append (")\n");

        var strb_files = new StringBuilder ("set(srcfiles\n");
        var strb_vapis = new StringBuilder ("set(vapifiles\n");
        foreach (var filepath in project.files) {
            var fname = project.get_relative_path (filepath);
            if (filepath.has_suffix (".vapi"))
                strb_vapis.append (@"\"$fname\"\n");
            else
                strb_files.append (@"\"$fname\"\n");
        }
        strb_files.append (")\n");
        strb_vapis.append (")\n");

        try {
            var file_stream = File.new_for_path (projectinfo).replace (
                                                    null,
                                                    false,
                                                    FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream (file_stream);
            /*
             * Don't translate this part to make collaboration with VCS and
             * multiple locales easier.
             */
            data_stream.put_string ("# This file was auto generated by Valama %s. Do not modify it.\n".printf (Config.PACKAGE_VERSION));
            //TODO: Check if file needs changes and set date accordingly.
            // var time = new DateTime.now_local();
            // data_stream.put_string ("# Last change: %s\n".printf (time.format ("%F %T")));
            data_stream.put_string (@"set(project_name \"$(project.project_name)\")\n");
            data_stream.put_string (@"set($(project.project_name)_VERSION \"$(project.version_major).$(project.version_minor).$(project.version_patch)\")\n");
            data_stream.put_string (strb_pkgs.str);
            data_stream.put_string (strb_files.str);
            data_stream.put_string (strb_vapis.str);

            data_stream.close();
        } catch (GLib.IOError e) {
            throw new BuildError.INITIALIZATION_FAILED (_("Could not read file: %s\n"), e.message);
        } catch (GLib.Error e) {
            throw new BuildError.INITIALIZATION_FAILED (_("Could not open file: %s\n"), e.message);
        }

        exit_status = 0;
        initialized = true;
        initialize_finished();
        return true;
    }

    public override bool configure(out int? exit_status = null) throws BuildError.INITIALIZATION_FAILED,
                                            BuildError.CONFIGURATION_FAILED {
        exit_status = null;
        if (!initialized && !initialize (out exit_status))
            return false;

        exit_status = null;
        configured = false;
        configure_started();

        var cmdline = new string[] {"cmake", ".."};

        Pid? pid;
        if (!call_cmd (cmdline, out pid)) {
            configure_finished();
            throw new BuildError.CONFIGURATION_FAILED (_("configuration failed"));
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = Process.exit_status (status);
            Process.close_pid (intpid);
            builder_loop.quit();
        });

        builder_loop.run();
        exit_status = exit;
        configured = true;
        configure_finished();
        return exit_status == 0;
    }

    public override bool build (out int? exit_status = null) throws BuildError.INITIALIZATION_FAILED,
                                        BuildError.CONFIGURATION_FAILED,
                                        BuildError.BUILD_FAILED {
        exit_status = null;
        if (!configured && !configure (out exit_status))
            return false;

        exit_status = null;
        built = false;
        build_started();
        var cmdline = new string[] {"make", "-j2"};

        Pid? pid;
        int? pstdout, pstderr;
        if (!call_cmd (cmdline, out pid, true, out pstdout, out pstderr)) {
            build_finished();
            throw new BuildError.CONFIGURATION_FAILED (_("build failed"));
        }

        var chn = new IOChannel.unix_new (pstdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            var output = channel_output_read_line (source, condition, out ret);
            Regex r = /^\[(?P<percent>.*)\%\].*$/;
            MatchInfo info;
            if (r.match (output, 0, out info)) {
                var percent_string = info.fetch_named ("percent");
                build_progress (int.parse (percent_string));
            }
            build_output (output);
            return ret;
        });

        var chnerr = new IOChannel.unix_new (pstderr);
        chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            build_output (channel_output_read_line (source, condition, out ret));
            return ret;
        });

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
