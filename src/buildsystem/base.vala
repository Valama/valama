/*
 * src/buildsystem/base.vala
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
using Gee;

public abstract class BuildSystem : Object {
    public string? buildpath { get; protected set; default = null; }

    public bool initialized { get; protected set; default = false; }
    public bool configured { get; protected set; default = false; }
    public bool built { get; protected set; default = false; }
    public bool cleaned { get; protected set; default = false; }
    public bool launched { get; protected set; default = false; }

    protected Pid? app_pid;
    public ProcessSignal? ps { get; protected set; default = null; }

    public signal void initialize_started();
    public signal void initialize_finished();
    public signal void configure_started();
    public signal void configure_finished();
    public signal void build_started();
    public signal void build_finished();
    public signal void clean_started();
    public signal void clean_finished();
    public signal void distclean_started();
    public signal void distclean_finished();
    public signal void runtests_started();
    public signal void runtests_finished();

    public signal void build_output (string output);
    public signal void build_progress (int percent);

    public signal void app_output (string output);

    protected MainLoop builder_loop;


    public BuildSystem() {
        builder_loop = new MainLoop();

        initialize_started.connect (() => {
            debug_msg (_("Buildsystem initialization started: %s\n"), this.get_name());
        });
        initialize_finished.connect (() => {
            debug_msg (_("Buildsystem initialization finished: %s\n"), this.get_name());
        });
        configure_started.connect (() => {
            debug_msg (_("Buildsystem configuration started: %s\n"), this.get_name());
        });
        configure_finished.connect (() => {
            debug_msg (_("Buildsystem configuration finished: %s\n"), this.get_name());
        });
        build_started.connect (() => {
            debug_msg (_("Buildsystem build started: %s\n"), this.get_name());
        });
        build_finished.connect (() => {
            debug_msg (_("Buildsystem build finished: %s\n"), this.get_name());
        });
        clean_started.connect (() => {
            debug_msg (_("Buildsystem cleaning started: %s\n"), this.get_name());
        });
        clean_finished.connect (() => {
            debug_msg (_("Buildsystem cleaning finished: %s\n"), this.get_name());
        });
        distclean_started.connect (() => {
            debug_msg (_("Buildsystem distcleaning started: %s\n"), this.get_name());
        });
        distclean_finished.connect (() => {
            debug_msg (_("Buildsystem distcleaning finished: %s\n"), this.get_name());
        });
        runtests_started.connect (() => {
            debug_msg (_("Buildsystem tests started: %s\n"), this.get_name());
        });
        runtests_finished.connect (() => {
            debug_msg (_("Buildsystem tests finished: %s\n"), this.get_name());
        });
    }

    public void init (ValamaProject? vproject = null) throws BuildError.INITIALIZATION_FAILED {
        var tmp_project = (vproject != null) ? vproject : project;
        if (tmp_project == null)
                throw new BuildError.INITIALIZATION_FAILED (_("Valama project not initialized"));
        if (buildpath == null)
            buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                         tmp_project.project_path,
                                         "build");
        tmp_project.defines_changed.connect ((added, define) => {
            if (added)
                register_define (define);
            else
                unregister_define (define);
        });
    }

    public static void init_dir (string path) throws BuildError.INITIALIZATION_FAILED {
        var f = File.new_for_path (path);
        try {
            if (!f.query_exists() && !f.make_directory_with_parents())
                throw new BuildError.INITIALIZATION_FAILED (_("directory creation failed: %s"),
                                                            path);
        } catch (GLib.Error e) {
            throw new BuildError.INITIALIZATION_FAILED (e.message);
        }
    }

    public abstract string get_executable();

    public virtual inline string get_executable_abs() {
        if (buildpath == null)
            return "";
        return Path.build_path (Path.DIR_SEPARATOR_S,
                                buildpath,
                                get_executable());
    }

    public abstract string get_name();
    public abstract string get_name_id();

    public abstract bool check_buildsystem_file (string filename);

    public bool executable_exists() {
        var fexe = File.new_for_path (get_executable_abs());
        return fexe.query_exists();
    }

    protected inline int? get_exit (int status) {
        if (Process.if_exited (status)) {
            ps = null;
            return Process.exit_status (status);
        } else if (Process.if_signaled (status)) {
            ps = Process.term_sig (status);
            return null;
        }
        bug_msg (_("Unknown status: %d - %s\n"), status, "BuildSystem.get_exit");
        return null;
    }

    protected virtual void register_define (string define) {
        string package;
        if (guess_pkg_by_define (define, out package)) {
            if (project.define_set (define))
                debug_msg (_("Enable define for package '%s': %s\n"), package, define);
        } else
            project.define_set (define, false);
    }

    protected virtual void unregister_define (string define) {
        if (project.unset_define (define))
            debug_msg (_("Disable define: %s\n"), define);
    }

    protected bool guess_pkg_by_define (string define, out string? package = null) {
        package = null;

        var digits = /^\d+$/;
        var alpha = /^[a-z]+$/;

        var defparts = define.split ("_");
        string[] pkg_name = {""};
        string[] pkg_ver = {""};
        VersionRelation? pkg_rel = null;
        for (int i = 0; i < defparts.length; ++i) {
            var check = defparts[i].down();

            if (digits.match (check)) {
                if (i == 0)
                    return false;
                var pkg_ver_tmp = pkg_ver;
                for (int j = 0; j < pkg_ver_tmp.length; ++j) {
                    if (i != 0) {
                        pkg_ver += @"$(pkg_ver[j])-$check";
                        pkg_ver += @"$(pkg_ver[j]).$check";
                    }
                    pkg_ver[j] = pkg_ver[j] + check;
                }
                if (pkg_rel == null) {
                    var pkg_name_tmp = pkg_name;
                    for (int j = 0; j < pkg_name_tmp.length; ++j) {
                        pkg_name += @"$(pkg_name[j])-$check";
                        if ((pkg_name[j][pkg_name[j].length-1]).isdigit())
                            pkg_name += @"$(pkg_name[j]).$check";
                        pkg_name += @"$(pkg_name[j])$check";
                    }
                }
            } else if (alpha.match (check)) {
                var pkg_name_tmp = pkg_name;
                for (int j = 0; j < pkg_name_tmp.length; ++j) {
                    if (check == "gtk")
                        pkg_name += @"$(pkg_name[j])gtk+";
                    if (check == "valac") {
                        pkg_name += @"$(pkg_name[j])vala";
                        if (i == 0)
                            pkg_name += @"lib$(pkg_name[j])vala";
                    }
                    if (i == 0)
                        pkg_name += @"lib$check";
                    else
                        pkg_name += @"$(pkg_name[j])-$check";
                    pkg_name[j] = @"$(pkg_name[j])$check";
                }
            }
        }

        foreach (var name in pkg_name) {
            string[] checks = {name};
            if ((name[name.length-1]).isdigit())
                checks += @"$name.0";
            foreach (var check in checks)
                if (check in project.packages.get_keys()) {
                    package = check;
                    return true;
                }
        }

        debug_msg (_("Unable to guess package for define: %s\n"), define);
        return false;
    }

    public virtual bool launch (string[] cmdparams = {}, out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED,
                                               BuildError.CONFIGURATION_FAILED,
                                               BuildError.BUILD_FAILED,
                                               BuildError.LAUNCHING_FAILED {
        launched = false;
        app_pid = null;
        exit_status = null;
        if (!executable_exists() && (built || build())) {
            warning_msg (_("Project already built but executable does not exist: %s\n"),
                         get_executable_abs());
            return false;
        }

        string[] cmdline = { get_executable_abs() };
        foreach (var param in cmdparams)
            cmdline += param;

        int? pstdout, pstderr;
        if (!call_cmd (cmdline, out app_pid, true, out pstdout, out pstderr))
            throw new BuildError.LAUNCHING_FAILED (_("launching failed"));

        var chn = new IOChannel.unix_new (pstdout);
        chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            app_output (channel_output_read_line (source, condition, out ret));
            return ret;
        });
        var chnerr = new IOChannel.unix_new (pstderr);
        chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            app_output (channel_output_read_line (source, condition, out ret));
            return ret;
        });

        int? exit = null;
        ChildWatch.add (app_pid, (intpid, status) => {
            launched = false;
            exit = get_exit (status);
            builder_loop.quit();
        });

        launched = true;
        builder_loop.run();
        exit_status = exit;
        app_pid = null;
        return exit_status == 0;
    }

    public virtual void launch_kill() {
        if (!launched)
            return;

        builder_loop.quit();
        //TODO: Does this work on Windows?
        Posix.kill (app_pid, 15);
        Process.close_pid (app_pid);
    }

    public virtual bool preparate() throws BuildError.INITIALIZATION_FAILED {
        if (buildpath == null)
            throw new BuildError.INITIALIZATION_FAILED (_("Build directory not set."));
        init_dir (buildpath);
        return true;
    }

    public virtual bool initialize (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED {
        exit_status = null;
        if (!preparate())
            return false;

        exit_status = 0;
        initialized = true;
        return true;
    }

    public virtual bool configure (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED,
                                               BuildError.CONFIGURATION_FAILED {
        exit_status = null;
        if (!initialized && !initialize (out exit_status))
            return false;
        exit_status = 0;
        configured = true;
        return true;
    }

    public virtual bool build (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED,
                                               BuildError.CONFIGURATION_FAILED,
                                               BuildError.BUILD_FAILED {
        exit_status = null;
        if (!configured && !configure (out exit_status))
            return false;
        exit_status = 0;
        built = true;
        return true;
    }

    public virtual bool clean (out int? exit_status = null)
                                        throws BuildError.CLEAN_FAILED {
        exit_status = 0;
        cleaned = true;
        return true;
    }

    public virtual bool distclean (out int? exit_status = null)
                                        throws BuildError.CLEAN_FAILED {
        exit_status = 0;
        cleaned = true;
        return true;
    }

    public virtual bool runtests (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED,
                                               BuildError.CONFIGURATION_FAILED,
                                               BuildError.BUILD_FAILED,
                                               BuildError.TEST_FAILED {
        exit_status = null;
        if (!built && !build (out exit_status))
            return false;
        exit_status = 0;
        return true;
    }

    protected static TreeMap<string, PkgBuildInfo> get_pkgmaps() {
        var pkgmaps = new TreeMap<string, PkgBuildInfo> (null, PkgBuildInfo.compare_name);

        foreach (var pkg in project.packages.get_values()) {
            pkgmaps.set (pkg.name, new PkgBuildInfo (pkg.name,
                                                     pkg.version,
                                                     pkg.rel));
            if (pkg.choice != null && pkg.choice.all)
                foreach (var pkg_choice in pkg.choice.packages)
                    if (pkg != pkg_choice)
                        pkgmaps.set (pkg_choice.name,
                                     new PkgBuildInfo (pkg_choice.name,
                                                       pkg_choice.version,
                                                       pkg_choice.rel,
                                                       pkg.name));
        }

        foreach (var pkgname in project.get_all_packages())
            if (!pkgmaps.has_key (pkgname))
                pkgmaps.set (pkgname, new PkgBuildInfo (pkgname, null, null,
                                                        null, false));

        return pkgmaps;
    }

    protected bool call_cmd (string[]? cmdline, out Pid? outpid = null, bool manual = false,
                            out int? out_stdout = null, out int? out_stderr = null) {
        outpid = null;
        out_stdout = null;
        out_stderr = null;
        if (cmdline == null)
            return false;

        Pid? pid = null;
        int pstdout;
        int pstderr;
        try {
            Process.spawn_async_with_pipes (buildpath,
                                            cmdline,
                                            null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            null,
                                            out pid,
                                            null,
                                            out pstdout,
                                            out pstderr);
            outpid = pid;
            out_stdout = pstdout;
            out_stderr = pstderr;
        } catch (GLib.SpawnError e) {
            errmsg (_("Could not spawn subprocess: %s\n"), e.message);
            return false;
        }

        if (!manual) {
            var chn = new IOChannel.unix_new (pstdout);
            chn.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
                bool ret;
                build_output (channel_output_read_line (source, condition, out ret));
                return ret;
            });
            var chnerr = new IOChannel.unix_new (pstderr);
            chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
                bool ret;
                build_output (channel_output_read_line (source, condition, out ret));
                return ret;
            });
        }

        return true;
    }

    protected static string channel_output_read_line (IOChannel source,
                                             IOCondition condition,
                                             out bool return_value) {
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
}


public class PkgBuildInfo : PackageInfo {
    public override string name { get; private set; }
    public override string? version { get; private set; default = null; }
    public override VersionRelation? rel { get; private set; default = null; }
    public string? choice_pkg { get; private set; }
    public bool link { get; private set; }
    public bool check { get; private set; }

    public PkgBuildInfo (string name, string? version = null, VersionRelation? rel = null,
                         string? choice_pkg = null, bool link = true, bool check = true) {
        this.name = name;
        if (version != null && rel != null) {
            this.version = version;
            this.rel = rel;
        }
        this.choice_pkg = choice_pkg;
        if (check) {
            this.check = package_exists (name);
            if (this.check)
                this.link = link;
            else
                this.link = false;
        } else
            this.check = this.link = false;
    }

    /**
     * Compare two {@link PkgBuildInfo} instances by name.
     *
     * @param a First instance.
     * @param b Second instance.
     * @return `true` if a.name == b.name.
     */
    public static inline bool compare_name (PkgBuildInfo a, PkgBuildInfo b) {
        return (a.name == b.name);
    }

    public new string to_string() {
        var openb = true;
        var closeb = false;
        var strb = new StringBuilder ((this as PackageInfo).to_string());
        str_opt (ref strb, ref openb, ref closeb, !check, "nocheck");
        str_opt (ref strb, ref openb, ref closeb, !link, "nolink");
        if (closeb)
            strb.append ("}");
        return strb.str;
    }

    private inline void str_opt (ref StringBuilder strb, ref bool openb,
                                        ref bool closeb, bool cond, string opt) {
        if (cond) {
            if (openb) {
                strb.append (" {");
                openb = false;
            } else
                strb.append (",");
            strb.append (opt);
            closeb = true;
        }
    }
}


public static bool package_exists (string package_name,
                                   out string? package_version = null) {
    var pc = @"pkg-config --modversion $package_name";
    int exit_status;

    try {
        string err;  // don't print error to console output
        Process.spawn_command_line_sync (pc, out package_version, out err, out exit_status);
        return (0 == exit_status);
    } catch (SpawnError e) {
        warning_msg (_("Could not spawn pkg-config package existence check: %s\n"), e.message);
        return false;
    }
}


public errordomain BuildError {
    INITIALIZATION_FAILED,
    CONFIGURATION_FAILED,
    BUILD_FAILED,
    CLEAN_FAILED,
    TEST_FAILED,
    LAUNCHING_FAILED
}

// vim: set ai ts=4 sts=4 et sw=4
