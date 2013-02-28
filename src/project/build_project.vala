/*
 * src/project/build_project.vala
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
using Guanako;
using Gee;

public class ProjectBuilder : Object{
    private ValamaProject project;
    public bool app_running { public get; private set; }
    private Pid app_pid;
    private bool project_needs_compile = false;

    public ProjectBuilder (ValamaProject project) {
        this.project = project;
        project.buffer_changed.connect((has_changes)=>{
            if (has_changes)
                project_needs_compile = true;
        });
        project.notify["idemode"].connect(() => {
            project_needs_compile = true;
        });
    }

    public signal void app_output_std (string output);
    public signal void app_output_err (string output);

    public signal void build_started ();
    public signal void build_output (string output);
    public signal void build_progress (int percent);
    public signal void build_finished ();
    public signal void app_state_changed (bool app_running);

    /**
     * Build project.
     *
     * @return Return true on success else false.
     */
    //FIXME: Currently no check if build was successful.
    public bool build_project () {
        var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                         project.project_path,
                                         "build");
        var builddir = File.new_for_path (buildpath);
        try {
        if (!builddir.query_exists() && !builddir.make_directory())
            return false;
        } catch (GLib.Error e) {
            errmsg (_("Could not create directory '%s': %s\n"), buildpath, e.message);
        }

        build_started();

        int exitstatus = 0;

        if (project.buildsystem == "valama") {
            string[] valacargs = new string[] {"valac"};
            valacargs += "--thread";
            valacargs += "--output=" + project.project_name.casefold();
            foreach (string pkg in project.guanako_project.packages)
                valacargs += "--pkg=" + pkg;
            if (project.idemode != IdeModes.DEBUG){
                foreach (Vala.SourceFile file in project.guanako_project.get_source_files())
                    valacargs += file.filename;
            } else {
                int cnt = 0;
                foreach (string src_file_path in project.files){
                    if (src_file_path.has_suffix (".vapi"))
                        continue;
                    string content = "";
                    try {
                        FileUtils.get_contents (src_file_path, out content);
                    } catch (GLib.FileError e) {
                        errmsg (_("Could read file content of '%s': %s\n"), src_file_path, e.message);
                    }
                    var srcfile = project.guanako_project.get_source_file_by_name(src_file_path);
                    srcfile.content = content; //TODO: Find out why SourceFile.content is empty at the beginning (??)
                    var tmppath = Path.build_path (Path.DIR_SEPARATOR_S, buildpath, cnt.to_string() + ".vala");
                    var tmpfile = File.new_for_path (tmppath);

                    try {
                        var dos = new DataOutputStream (tmpfile.replace (null, false, FileCreateFlags.REPLACE_DESTINATION));
                        dos.put_string (frankenstein.frankensteinify_sourcefile(srcfile));
                        if (cnt == 0)
                            dos.put_string (frankenstein.get_frankenstein_mainblock());
                    } catch (GLib.IOError e) {
                        errmsg (_("Could not update file: %s\n"), e.message);
                    } catch (GLib.Error e) {
                        errmsg (_("Could not open file to write: %s\n"), e.message);
                    }
                    valacargs += tmppath;
                    cnt++;
                }
            }
            Pid valac_pid;
            int valac_stdout;
            int valac_error;
            try {
                Process.spawn_async_with_pipes (buildpath,
                                                valacargs,
                                                null,
                                                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                                null,
                                                out valac_pid,
                                                null,
                                                out valac_stdout,
                                                out valac_error);
            } catch (GLib.SpawnError e) {
                errmsg (_("Could not spawn subprocess: %s\n"), e.message);
            }
            var chn = new IOChannel.unix_new (valac_stdout);
            chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
                bool ret;
                build_output(channel_output_read_line (source, condition, out ret));
                return ret;
            });
            var chnerr = new IOChannel.unix_new (valac_error);
            chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
                bool ret;
                build_output(channel_output_read_line (source, condition, out ret));
                return ret;
            });
            build_output (_("Adding valac watch\n"));
            ChildWatch.add (valac_pid, (pid, status) => {
                Process.close_pid (pid);
                build_finished();
                project_needs_compile = false;
            });
            return true;
        }

        /* Write project.cmake */
        try {
            string pkg_list = "set(required_pkgs\n";
            var chpkgs = new TreeSet<string>();
            foreach (var choice in project.package_choices)
                if (choice.all)
                    foreach (var pkg in choice.packages)
                        chpkgs.add (pkg);
            chpkgs.add_all (project.guanako_project.packages);
            foreach (string pkg in chpkgs)
                pkg_list += @"\"$pkg\"\n";
            pkg_list += ")\n";

            string srcfiles = "set(srcfiles\n";
            string vapifiles = "set(vapifiles\n";
            foreach (var filepath in project.files) {
                var fname = project.get_relative_path (filepath);
                if (filepath.has_suffix (".vapi")) {
                    vapifiles += @"\"$fname\"\n";
                } else {
                    srcfiles += @"\"$fname\"\n";
                }
            }
            srcfiles += ")\n";
            vapifiles += ")\n";

            var file_stream = File.new_for_path (
                                    Path.build_path (Path.DIR_SEPARATOR_S,
                                                     project.project_path,
                                                     "cmake",
                                                     "project.cmake")).replace(
                                                            null,
                                                            false,
                                                            FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream (file_stream);
            /*
             * Don't translate this part to make collaboration with vcs and
             * multiple locales easier.
             */
            data_stream.put_string ("# This file was auto generated by Valama %s. Do not modify it.\n".printf (Config.PACKAGE_VERSION));
            // var time = new DateTime.now_local();
            // data_stream.put_string ("# Last change: %s\n".printf (time.format ("%F %T")));
            data_stream.put_string (@"set(project_name \"$(project.project_name)\")\n");
            data_stream.put_string (@"set($(project.project_name)_VERSION \"$(project.version_major).$(project.version_minor).$(project.version_patch)\")\n");
            data_stream.put_string (pkg_list);
            data_stream.put_string (srcfiles);
            data_stream.put_string (vapifiles);

            data_stream.close();
        } catch (GLib.IOError e) {
            errmsg (_("Could not read file: %s\n"), e.message);
        } catch (GLib.Error e) {
            errmsg (_("Could not open file: %s\n"), e.message);
        }

        build_output (_("Launching cmake...\n"));
        Pid cmake_pid;
        int cmake_stdout;
        int cmake_error;
        try {
            Process.spawn_async_with_pipes (buildpath,
                                            new string[]{ "cmake", ".." },
                                            null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out cmake_pid,
                                            null,
                                            out cmake_stdout,
                                            out cmake_error);
        } catch (GLib.SpawnError e) {
            errmsg (_("Could not spawn subprocess: %s\n"), e.message);
        }
        var chn = new IOChannel.unix_new (cmake_stdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
            bool ret;
            build_output(channel_output_read_line (source, condition, out ret));
            return ret;
        });
        var chn_err = new IOChannel.unix_new (cmake_error);
        chn_err.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
            bool ret;
            build_output(channel_output_read_line (source, condition, out ret));
            return ret;
        });

        build_output (_("Adding cmake watch\n"));
        ChildWatch.add (cmake_pid, (pid, status) => {
            Process.close_pid (pid);
            build_output (_("Launching make...\n"));
            Pid make_pid;
            int make_stdout;
            int make_error;
            try {
                Process.spawn_async_with_pipes (buildpath,
                                                new string[]{ "make", "-j4" },
                                                null,
                                                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                                null,
                                                out make_pid,
                                                null,
                                                out make_stdout,
                                                out make_error);
            } catch (GLib.SpawnError e) {
                errmsg (_("Could not spawn subprocess: %s\n"), e.message);
            }
            var chn_make = new IOChannel.unix_new (make_stdout);
            chn_make.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
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
            var chn_make_err = new IOChannel.unix_new (make_error);
            chn_make_err.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
                bool ret;
                build_output(channel_output_read_line (source, condition, out ret));
                return ret;
            });
            ChildWatch.add (make_pid, (pid, status) => {
                Process.close_pid (pid);
                build_finished();
                project_needs_compile = false;
            });
        });

        if (exitstatus == 0)
            return true;
        return false;
    }
    private string channel_output_read_line (IOChannel source, IOCondition condition, out bool return_value) {
        if (condition == IOCondition.HUP) {
            return_value = false;
            return "";
        }
        string output = "";
        try {
            source.read_line (out output, null, null);
        } catch (GLib.ConvertError e) {
            errmsg (_("Could not convert all characters: %s\n"), e.message);
        } catch (GLib.IOChannelError e) {
            errmsg (_("IOChannel operation failed: %s\n"), e.message);
        }
        return_value = true;
        return output;
    }

    /**
     * Launch application (and build if necessary).
     */
    ulong handler_id;
    public void launch() {
        if (app_running)
            return;

        if (project_needs_compile) {
            build_project();
            handler_id = build_finished.connect (()=>{
                internal_launch();
                this.disconnect (handler_id);
            });
        } else
            internal_launch();
    }

    private void internal_launch() {
        var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                         project.project_path,
                                         "build");
        var filename = project.project_name.casefold();
        var filename_abs = Path.build_path (Path.DIR_SEPARATOR_S,
                                            buildpath,
                                            filename);
        var exefile = File.new_for_path (filename_abs);
        if (!exefile.query_exists()) {
            if (build_project()) {
                exefile = File.new_for_path (filename_abs);
                if (!exefile.query_exists()) {
                    bug_msg (_("Could not launch application: %s\n"), filename_abs);
                    return;
                }
            } else
                return;
        }

        int app_stdout;
        int app_stderr;
        try {
            Process.spawn_async_with_pipes (buildpath,
                                            new string[]{ filename },
                                            null,
                                            SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out app_pid,
                                            null,
                                            out app_stdout,
                                            out app_stderr);
        } catch (GLib.SpawnError e) {
            errmsg (_("Could not spawn subprocess: %s\n"), e.message);
        }
        _app_running = true;
        app_state_changed (true);

        var chn = new IOChannel.unix_new (app_stdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            app_output_std(channel_output_read_line (source, condition, out ret));
            return ret;
        });
        var chnerr = new IOChannel.unix_new (app_stderr);
        chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            app_output_err(channel_output_read_line (source, condition, out ret));
            return ret;
        });
        ChildWatch.add (app_pid, (pid, status) => {
            Process.close_pid (pid);
            app_running = false;
            app_state_changed (false);
        });
    }

    public void quit() {
        if (!_app_running)
            return;
        try {
            Process.spawn_command_line_sync ("kill " + app_pid.to_string());
        } catch (GLib.SpawnError e) {
            errmsg (_("Could not spawn subprocess: %s\n"), e.message);
        }
        Process.close_pid (app_pid);
        app_running = false;
        app_state_changed (false);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
