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
    public string buildpath { get; protected set; }

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

    public BuildSystem() {
        buildpath = Path.build_path (Path.DIR_SEPARATOR_S,
                                     project.project_path,
                                     "build");
    }

    public virtual void init_dir (string path) throws BuildError.INITIALIZATION_FAILED {
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

    public virtual bool initialize() {
        return true;
    }

    public virtual bool configure() {
        return true;
    }

    public virtual bool build() {
        return true;
    }

    public virtual bool clean() {
        return true;
    }

    public virtual bool distclean() {
        return true;
    }

    public virtual bool runtests() {
        return true;
    }

    protected TreeMap<string, PkgBuildInfo> get_pkgmaps() {
        var pkgmaps = new TreeMap<string, PkgBuildInfo> (null, PkgBuildInfo.compare_name);

        foreach (var pkg in project.packages) {
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

        foreach (var pkgname in project.guanako_project.get_context_packages())
            if (!pkgmaps.has_key (pkgname))
                pkgmaps.set (pkgname, new PkgBuildInfo (pkgname, null, null,
                                                        null, false));

        return pkgmaps;
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


/* Copy from Vala.CCodeCompiler (valac). */
public static bool package_exists (string package_name) {
    var pc = @"pkg-config --exists $package_name";
    int exit_status;

    try {
        Process.spawn_command_line_sync (pc, null, null, out exit_status);
        return (0 == exit_status);
    } catch (SpawnError e) {
        warning_msg (_("Could not spawn pkg-config package existence check: %s\n"), e.message);
        return false;
    }
}


public errordomain BuildError {
    INITIALIZATION_FAILED,
    CONFIGURATION_FAILED,
    BUILD_FAILED
}

// vim: set ai ts=4 sts=4 et sw=4
