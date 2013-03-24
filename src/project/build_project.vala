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

public class ProjectBuilder : Object {
    public bool app_running { get; private set; }
    private BuildSystem? launch_builder = null;

    private bool project_needs_compile = false;

    public ProjectBuilder() {
        project.buffer_changed.connect ((has_changes) => {
            if (has_changes)
                project_needs_compile = true;
        });
        project.notify["idemode"].connect (() => {
            project_needs_compile = true;
        });
    }

    public signal void build_started ();
    public signal void build_finished ();
    public signal void build_progress (int percent);
    public signal void build_output (string output);

    public signal void app_output (string output);

    /**
     * Build project.
     *
     * @return Return `true` on success else `false`.
     */
    public bool build_project (bool clean = false, bool tests = false,
                                bool distclean = false, bool cont = true) {
        build_started();

        string systemstr;
        try {
            var builder = get_builder (out systemstr);
            if (builder == null)
                return false;
            builder.build_output.connect ((output) => {
                build_output (output);
            });
            builder.build_progress.connect ((percent) => {
                build_progress (percent);
            });
            builder.notify["ps"].connect (() => {
                if (builder.ps != null) {
                    build_output ("--------------------------------------------\n");
                    build_output (_("Build command received signal: %s\n").printf (
                                builder.ps.to_string()));
                    build_output ("--------------------------------------------\n");
                }
            });

            int exit_status;
            builder.initialize (out exit_status);
            if (distclean && !builder.distclean (out exit_status)) {
                warning_msg (_("'Distclean' failed with exit status: %d\n"), exit_status);
                return false;
            } else if (clean && !builder.clean (out exit_status)) {
                warning_msg (_("'Clean' failed with exit status: %d\n"), exit_status);
                return false;
            }
            if (cont) {
                if (builder.configure (out exit_status)) {
                    if (builder.build (out exit_status)) {
                        project_needs_compile = false;
                        if (tests && !builder.runtests (out exit_status)) {
                            warning_msg (_("'Tests' failed with exit status: %d\n"), exit_status);
                            return false;
                        }
                    } else {
                        warning_msg (_("'Build' failed with exit status: %d\n"), exit_status);
                        return false;
                    }
                } else {
                    warning_msg (_("'Configure' failed with exit status: %d\n"), exit_status);
                    return false;
                }
            }
        } catch (BuildError.INITIALIZATION_FAILED e) {
            warning_msg (_("%s initialization failed: %s\n"), systemstr, e.message);
            return false;
        } catch (BuildError.CLEAN_FAILED e) {
            warning_msg (_("%s cleaning failed: %s\n"), systemstr, e.message);
            return false;
        } catch (BuildError.CONFIGURATION_FAILED e) {
            warning_msg (_("%s configuration failed: %s\n"), systemstr, e.message);
            return false;
        } catch (BuildError.BUILD_FAILED e) {
            warning_msg (_("%s build failed: %s\n"), systemstr, e.message);
            return false;
        } catch (BuildError.TEST_FAILED e) {
            warning_msg (_("%s tests failed: %s\n"), systemstr, e.message);
            return false;
        } finally {
            build_finished();
        }
        return true;
    }

    private BuildSystem? get_builder (out string? systemstr = null)
                                                throws BuildError.INITIALIZATION_FAILED {
        BuildSystem? builder;
        switch (project.buildsystem) {
            case "valama":
                systemstr = BuilderPlain.get_name_static();
                builder = new BuilderPlain();
                break;
            case "cmake":
                systemstr = BuilderCMake.get_name_static();
                builder = new BuilderCMake();
                break;
            default:
                warning_msg (_("Build system '%s' not supported.\n"), project.buildsystem);
                systemstr = null;
                return null;
        }
        return builder;
    }

    /**
     * Launch application (and build if necessary).
     */
    public void launch (string[] cmdparams = {}) {
        if (app_running) {
            warning_msg (_("Application still running. Quit it manually.\n"));
            return;
        }

        if (!project_needs_compile || build_project())
            internal_launch (cmdparams);
    }

    private void internal_launch (string[] cmdparams = {}) {
        try {
            launch_builder = get_builder();
            if (launch_builder == null)
                return;
            launch_builder.build_output.connect ((output) => {
                build_output (output);
            });
            launch_builder.app_output.connect ((output) => {
                app_output (output);
            });
            launch_builder.notify["ps"].connect (() => {
                if (launch_builder.ps != null) {
                    app_output ("--------------------------------------------\n");
                    app_output (_("Application received signal: %s\n").printf (
                                launch_builder.ps.to_string()));
                    app_output ("--------------------------------------------\n");
                }
            });

            app_running = true;
            int? exit_status;
            launch_builder.launch (cmdparams, out exit_status);
            if (exit_status != null) {
                app_output ("--------------------------------------------\n");
                /*
                 * Cast exit_status explicitly to int otherwise printf would
                 * give use some garbage.
                 */
                app_output (_("Application terminated with exit status: %d\n").printf (
                                                                    (int) exit_status));
                app_output ("--------------------------------------------\n");
            }
            app_running = false;
        } catch (BuildError e) {
            warning_msg (_("Launching application failed: %s\n"), e.message);
            return;
        }
    }

    public void quit() {
        if (!app_running)
            return;
        app_running = false;
        launch_builder.launch_kill();
    }
}

// vim: set ai ts=4 sts=4 et sw=4
