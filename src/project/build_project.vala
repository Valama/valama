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

    private bool project_needs_compile = false;
    private bool initialized = false;

    public signal void build_started (bool clear);
    public signal void build_finished (bool success);
    public signal void build_progress (int percent);
    public signal void build_output (string output);

    public signal void app_output (string output);


    public ProjectBuilder() {
        project.buffer_changed.connect ((has_changes) => {
            if (has_changes)
                project_needs_compile = true;
        });
        project.notify["idemode"].connect (() => {
            project_needs_compile = true;
        });
        init();
    }

    public void request_compile() {
        project_needs_compile = true;
    }

    private bool init() {
        if (initialized)
            return true;
        if (project.builder == null)
            return false;
        project.builder.build_output.connect ((output) => {
            build_output (output);
        });
        project.builder.build_progress.connect ((percent) => {
            build_progress (percent);
        });
        project.builder.app_output.connect ((output) => {
            app_output (output);
        });
        project.builder.notify["ps"].connect (() => {
            if (project.builder.ps != null) {
                build_output ("--------------------------------------------\n");
                build_output (_("Build command received signal: %s\n").printf (
                            project.builder.ps.to_string()));
                build_output ("--------------------------------------------\n");
            }
        });
        initialized = true;
        return true;
    }

    /**
     * Build project.
     *
     * @return Return `true` on success else `false`.
     */
    public bool build_project (bool clean = false, bool tests = false,
                                bool distclean = false, bool cont = true,
                                bool clear = true) {
        build_started (clear);

        if (!init()) {
            build_finished(false);
            return false;
        }

        try {
            int? exit_status;
            if (!project.builder.initialize (out exit_status)) {
                warning_msg (_("'Initialization' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
            if (distclean && !project.builder.distclean (out exit_status)) {
                warning_msg (_("'Distclean' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            } else if (clean && !project.builder.clean (out exit_status)) {
                warning_msg (_("'Clean' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
            if (cont) {
                if (project.builder.configure (out exit_status)) {
                    if (project.builder.build (out exit_status)) {
                        project_needs_compile = false;
                        if (tests && !project.builder.runtests (out exit_status)) {
                            warning_msg (_("'Tests' failed with exit status: %d\n"), (int) exit_status);
                            build_finished (false);
                            return false;
                        }
                    } else {
                        warning_msg (_("'Build' failed with exit status: %d\n"), (int) exit_status);
                        build_finished (false);
                        return false;
                    }
                } else {
                    warning_msg (_("'Configure' failed with exit status: %d\n"), (int) exit_status);
                    build_finished (false);
                    return false;
                }
            }
        } catch (BuildError.INITIALIZATION_FAILED e) {
            warning_msg (_("'%s' initialization failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.CLEAN_FAILED e) {
            warning_msg (_("'%s' cleaning failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.CONFIGURATION_FAILED e) {
            warning_msg (_("'%s' configuration failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.BUILD_FAILED e) {
            // TRANSLATORS:
            // E.g. "CMake build failed: some error" or "Autotools build failed: some error"
            warning_msg (_("'%s' build failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.TEST_FAILED e) {
            warning_msg (_("'%s' tests failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        }
        build_finished (true);
        return true;
    }

    /**
     * Clean up project build system files.
     *
     * @return `true` on success.
     */
    public bool clean_project (bool clear = true) {
        build_started (clear);
        if (!init()) {
            build_finished(false);
            return false;
        }
        try {
            int? exit_status;
            if (!project.builder.initialize (out exit_status)) {
                warning_msg (_("'Initialization' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
            stdout.printf ("try to clean\n");
            if (!project.builder.clean (out exit_status)) {
                warning_msg (_("'Distclean' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
        } catch (BuildError.INITIALIZATION_FAILED e) {
            warning_msg (_("'%s' initialization failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.CLEAN_FAILED e) {
            warning_msg (_("'%s' cleaning failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        }
        build_finished (true);
        return true;
    }

    /**
     * Clean up all project build system files.
     *
     * @return `true` on success.
     */
    public bool distclean_project (bool clear = true) {
        build_started (clear);
        if (!init()) {
            build_finished(false);
            return false;
        }
        try {
            int? exit_status;
            if (!project.builder.initialize (out exit_status)) {
                warning_msg (_("'Initialization' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
            if (!project.builder.distclean (out exit_status)) {
                warning_msg (_("'Distclean' failed with exit status: %d\n"), (int) exit_status);
                build_finished (false);
                return false;
            }
        } catch (BuildError.INITIALIZATION_FAILED e) {
            warning_msg (_("'%s' initialization failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        } catch (BuildError.CLEAN_FAILED e) {
            warning_msg (_("'%s' cleaning failed: %s\n"), project.builder.get_name(), e.message);
            build_finished (false);
            return false;
        }
        build_finished (true);
        return true;
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
        if (!init())
            return;

        project.builder.notify["ps"].connect (() => {
            if (project.builder.ps != null) {
                app_output ("--------------------------------------------\n");
                app_output (_("Application received signal: %s\n").printf (
                            project.builder.ps.to_string()));
                app_output ("--------------------------------------------\n");
            }
        });

        try {
            app_running = true;
            int? exit_status;
            project.builder.launch (cmdparams, out exit_status);
            if (exit_status != null) {
                app_output ("--------------------------------------------\n");
                /*
                 * Cast exit_status explicitly to int otherwise printf would
                 * give use some garbage.
                 */
                app_output (_("Application terminated with exit status '%d'.\n").printf (
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
        project.builder.launch_kill();
    }
}

// vim: set ai ts=4 sts=4 et sw=4
