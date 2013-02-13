/*
 * src/build_project.vala
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
using Guanako;

public class ProjectBuilder {

    public ProjectBuilder (ValamaProject project){
        this.project = project;
    }

    ValamaProject project;

    public signal void buildsys_output (string output);
    public signal void buildsys_progress (int percent);
    public signal void app_state_changed (bool app_running);
    public bool app_running { public get; private set; }

    /**
     * Build project.
     *
     * @return Return true on success else false.
     */
    public bool build_project(FrankenStein? stein = null) {
        //if (!buffer_save_all())
        //    return false;
        if (project.buildsystem == "valama"){
            var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                             project.project_path,
                                             "build");
            string[] valacargs = new string[] {"valac"};
            valacargs += "--thread";
            valacargs += "--output=" + project.project_name.casefold();
            foreach (string pkg in project.guanako_project.packages)
                valacargs += "--pkg=" + pkg;
            if (stein == null){
                foreach (Vala.SourceFile file in project.guanako_project.get_source_files())
                    valacargs += file.filename;
            } else {
                int cnt = 0;
                foreach (string src_file_path in project.files){
                    if (src_file_path.has_suffix (".vapi"))
                        continue;
                    string content;
                    FileUtils.get_contents(src_file_path, out content);
                    var srcfile = project.guanako_project.get_source_file_by_name(src_file_path);
                    srcfile.content = content; //TODO: Find out why SourceFile.content is empty at the beginning (??)
                    var tmppath = Path.build_path (Path.DIR_SEPARATOR_S, buildpath, cnt.to_string() + ".vala");
                    var tmpfile = File.new_for_path (tmppath);
                    
                    var dos = new DataOutputStream (tmpfile.replace (null, false, FileCreateFlags.REPLACE_DESTINATION));
                    dos.put_string (stein.frankensteinify_sourcefile(srcfile));
                    if (cnt == 0)
                        dos.put_string (stein.get_frankenstein_mainblock());
                    valacargs += tmppath;
                    cnt++;
                }
            }
            Pid valac_pid;
            int valac_stdout;
            int valac_error;
            Process.spawn_async_with_pipes (buildpath,
                                            valacargs,
                                            null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out valac_pid,
                                            null,
                                            out valac_stdout,
                                            out valac_error);
            var chn = new IOChannel.unix_new (valac_stdout);
            chn.add_watch (IOCondition.IN | IOCondition.HUP, (source)=>{
                string output;
                size_t len;
                source.read_to_end (out output, out len);
                buildsys_output (output);
                return false;
            });
            var chnerr = new IOChannel.unix_new (valac_error);
            chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source)=>{
                string output;
                size_t len;
                source.read_to_end (out output, out len);
                buildsys_output (output);
                return false;
            });
            buildsys_output ("Adding valac watch\n");
            ChildWatch.add (valac_pid, (pid, status) => {
                Process.close_pid (pid);
            });
            return true;
        }

        var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                         project.project_path,
                                         "build");
        DirUtils.create (buildpath, 755);  //TODO: Support umask
        /* Write project.cmake */
        try {
            string pkg_list = "set(required_pkgs\n";
            foreach (string pkg in project.guanako_project.packages)
                pkg_list += @"\"$pkg\"\n";
            pkg_list += ")\n";

            string srcfiles = "set(srcfiles\n";
            string vapifiles = "set(vapifiles\n";
            var pfile = File.new_for_path (project.project_path);
            foreach (var filepath in project.files) {
                var file = File.new_for_path (filepath);
                var fname = pfile.get_relative_path (file);
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
            data_stream.put_string ("# " + _("This file was auto generated by Valama %s. Do not modify it.\n").printf (Config.PACKAGE_VERSION));
            // var time = new DateTime.now_local();
            // data_stream.put_string ("# " + _("Last change: %s\n").printf (time.format("%F %T")));
            data_stream.put_string (@"set(project_name \"$(project.project_name)\")\n");
            data_stream.put_string (@"set($(project.project_name)_VERSION \"$(project.version_major).$(project.version_minor).$(project.version_patch)\")\n");
            data_stream.put_string (pkg_list);
            data_stream.put_string (srcfiles);
            data_stream.put_string (vapifiles);

            data_stream.close();
        } catch (GLib.IOError e) {
            stderr.printf (_("Could not read file: %s\n"), e.message);
        } catch (GLib.Error e) {
            stderr.printf (_("Could not open file: %s\n"), e.message);
        }

        int exitstatus = 0;
        buildsys_output ("Launching cmake...\n");
        Pid cmake_pid;
        int cmake_stdout;
        int cmake_error;
        Process.spawn_async_with_pipes (buildpath,
                                        new string[]{ "cmake", ".." },
                                        null,
                                        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                        null,
                                        out cmake_pid,
                                        null,
                                        out cmake_stdout,
                                        out cmake_error);
        var chn = new IOChannel.unix_new (cmake_stdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source)=>{
            string output;
            size_t len;
            source.read_to_end (out output, out len);
            buildsys_output (output);
            return false;
        });
        buildsys_output ("Adding cmake watch\n");
        ChildWatch.add (cmake_pid, (pid, status) => {
            Process.close_pid (pid);
            buildsys_output ("Launching make...\n");
            Pid make_pid;
            int make_stdout;
            int make_error;
            Process.spawn_async_with_pipes (buildpath,
                                            new string[]{ "make", "-j4" },
                                            null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out make_pid,
                                            null,
                                            out make_stdout,
                                            out make_error);
            var chn_make = new IOChannel.unix_new (make_stdout);
            chn_make.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition)=>{
                if (condition == IOCondition.HUP)
                    return false;
                string output;
                source.read_line (out output, null, null);
                buildsys_output (output);
                Regex r = /^\[(?P<percent>.*)\%\].*$/;
                MatchInfo info;
                if (r.match (output, 0, out info)) {
                    var percent_string = info.fetch_named ("percent");
                    buildsys_progress (percent_string.to_int());
                }
                return true;
            });
            ChildWatch.add (make_pid, (pid, status) => {
                Process.close_pid (pid);
            });
        });

        /*var chn2 = new IOChannel.unix_new (cmake_error);
        chn2.add_watch (IOCondition.IN | IOCondition.HUP, ()=>{
            string output;
            size_t len;
            chn2.read_to_end (out output, out len);
            buildsys_output (output);
            stdout.printf ("==================" + output + "\n");
            return true;
        });*/

        //buildsys_output (chn.read_to_end());
        /*string curdir = Environment.get_current_dir();
        try {
            var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                             project.project_path,
                                             "build");
            DirUtils.create (buildpath, 755);  //TODO: Support umask
            Environment.set_current_dir (buildpath);
            //TODO; Use GLib.Process.spawn_async_with_pipes.
            Process.spawn_command_line_sync ("cmake ..", null, null, out exitstatus);
            if (exitstatus == 0)
                Process.spawn_command_line_sync ("make", null, null, out exitstatus);
        } catch (GLib.SpawnError e) {
            stderr.printf(_("Could not execute build process: %s\n"), e.message);
            return false;
        } finally {
            Environment.set_current_dir (curdir);
        }*/
        if (exitstatus == 0)
            return true;
        return false;
    }

    /**
     * Launch application.
     */
    Pid app_pid;
    public void launch (){
        if (app_running)
            return;
        var buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                         project.project_path,
                                         "build");
        int app_stdout;
        int app_error;
        Process.spawn_async_with_pipes (buildpath,
                                        new string[]{ 
                                            Path.build_path (Path.DIR_SEPARATOR_S, buildpath, project.project_name.casefold())
                                        },
                                        null,
                                        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                        null,
                                        out app_pid,
                                        null,
                                        out app_stdout,
                                        out app_error);
        _app_running = true;
        app_state_changed (true);
        var chn = new IOChannel.unix_new (app_stdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source)=>{
            string output;
            size_t len;
            source.read_to_end (out output, out len);
            buildsys_output (output);
            return false;
        });
        ChildWatch.add (app_pid, (pid, status) => {
            Process.close_pid (pid);
            app_running = false;
            app_state_changed (false);
        });
    }
    public void quit (){
        if (!_app_running)
            return;
        Process.spawn_command_line_sync ("kill " + app_pid.to_string());
        Process.close_pid (app_pid);
        app_running = false;
        app_state_changed (false);
    }

}

// vim: set ai ts=4 sts=4 et sw=4
