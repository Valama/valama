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
    
    public BuilderCMake (bool make_lib = false)
    {
        Object(library: make_lib);
    }

    public override string get_executable() {
        return project.project_name.down();
    }

    public override inline string get_name() {
        return "CMake";
    }

    public override inline string get_name_id() {
        return "cmake";
    }

    public override bool check_buildsystem_file (string filename) {
        return (filename.has_suffix (".cmake") ||
                Path.get_basename (filename) == ("CMakeLists.txt"));
    }

    public override bool preparate() throws BuildError.INITIALIZATION_FAILED {
        if (!base.preparate())
            return false;
        projectinfo = Path.build_path (Path.DIR_SEPARATOR_S,
                                       project.project_path,
                                       "cmake",
                                       "project.cmake");
        init_dir (Path.get_dirname (projectinfo));
        return true;
    }

    public override bool initialize (out int? exit_status = null)
                                        throws BuildError.INITIALIZATION_FAILED {
        exit_status = null;
        initialized = false;
        if (!preparate())
            return false;
        initialize_started();
        
        try {
        var cml = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                       project.project_path,
                                      "CMakeLists.txt")).replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
        var cml_stream = new DataOutputStream (cml);
        cml_stream.put_string ("""#
    # CMakeLists.txt
    # Copyright (C) 2012, 2013, Valama development team
    #
    # Valama is free software: you can redistribute it and/or modify it
    # under the terms of the GNU General Public License as published by the
    # Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.
    #
    # Valama is distributed in the hope that it will be useful, but
    # WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    # See the GNU General Public License for more details.
    #
    # You should have received a copy of the GNU General Public License along
    # with this program.  If not, see <http://www.gnu.org/licenses/>.
    #

    cmake_minimum_required(VERSION "2.8.4")

    include("${CMAKE_SOURCE_DIR}/cmake/project.cmake")
    include("${CMAKE_SOURCE_DIR}/cmake/Common.cmake")

    project("${project_name}" C)
    string(TOLOWER "${project_name}" project_name_lower)

    set(bindir "bin")
    set(datarootdir "share")
    set(libdir "lib")
    set(includedir "include")
    set(datadir "${datarootdir}/${project_name_lower}")
    set(uidir "${datadir}/ui")
    set(localedir "${datarootdir}/locale")
    set(appdir "${datarootdir}/applications")
    set(gsettingsdir "${datarootdir}/glib-2.0/schemas")
    set(pixrootdir "${datarootdir}/pixmaps")
    set(pixdir "${pixrootdir}/${project_name_lower}")
    set(docdir "${datadir}/doc")
    set(mandir "${datarootdir}/man")
    set(mimedir "${datarootdir}/mime/packages")
    if(CMAKE_INSTALL_PREFIX)
      set(install_prefix "${CMAKE_INSTALL_PREFIX}/")
    else()
      set(install_prefix)
    endif()

    list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/vala")
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

    find_package(Vala "0.20" REQUIRED)
    """);

    if (library) {
        cml_stream.put_string ("""set(pc_prefix ${CMAKE_INSTALL_PREFIX})
    set(pc_exec_prefix "\${prefix}")
    set(pc_libdir "\${exec_prefix}/${libdir}")
    set(pc_includedir "\${prefix}/${includedir}")
    set(pc_datarootdir "\${prefix}/${datarootdir}")
    set(pc_vapidir "\${datarootdir}/vala-${VALA_SHORTVER}/vapi")
    set(pc_version "${${project_name}_VERSION}")

    # Configure template files.
    set(stripped_pkgs)
    set(stripped_pkgs_pkgconfig)
    foreach(pkgstr ${required_pkgs})
      set(matchit)
      string(REGEX MATCH "([^{ \t]*)[ \t]*{([^}]+,|)[ \t]*nocheck[ \t]*(|,[^}]+)}[ \t]*$" matchit ${pkgstr})
      string(REGEX REPLACE "^([^{ \t]*)[ \t]*{[^{}]*}[ \t]*$" "\\1" pkg ${pkgstr})
      if(NOT matchit)
        list(APPEND stripped_pkgs_pkgconfig "${pkg}")
      endif()

      string(REGEX REPLACE "^([^ \t]+).*" "\\1"  pkg_pkgconfig "${pkgstr}")
      list(APPEND stripped_pkgs "${pkg_pkgconfig}")
    endforeach()
    base_list_to_delimited_string(pc_requirements
      DELIM " "
      BASE_LIST ${stripped_pkgs_pkgconfig}
    )
    configure_file("${project_name_lower}.pc.in" "${project_name_lower}.pc" @ONLY)
    
    base_list_to_delimited_string(deps_requirements
    DELIM "\n"
    BASE_LIST ${stripped_pkgs}
   )
   configure_file("${project_name_lower}.deps.in" "${project_name_lower}.deps")""");
   }

    cml_stream.put_string ("""# Custom library version checks.
    set(definitions)
    set(vapidirs)
    find_package(PkgConfig)
    # config
    list(REMOVE_ITEM required_pkgs "config {nocheck,nolink}")
    # gobject-2.0
    pkg_check_modules(GOBJECT2.0 REQUIRED "gobject-2.0")

    set(default_vala_flags
      "--thread"
      "--target-glib" "${GOBJECT2.0_VERSION}"
    )

    include(ValaPkgs)
    vala_pkgs(VALA_C
      PACKAGES
        ${required_pkgs}
      DEFINITIONS
        ${definitions}
      OPTIONAL
        ${optional_pkgs}
      SRCFILES
        ${srcfiles}""");
    if (library) {
        cml_stream.put_string ("""  LIBRARY
        "${project_name_lower}"
      GIRFILE
        "${project_name}-${${project_name}_VERSION}"""");
    }
    cml_stream.put_string ("""  VAPIS
        ${vapifiles}
      OPTIONS
        ${default_vala_flags}
        ${vapidirs}
    )
    """);
    string rflags = "";
    if (project.flags != null) {
		var flags = project.flags.split (" ");
		for (var i = 0; i < flags.length - 1; i++)
			if (flags[i] == "-X")
				rflags += " " + flags[i + 1];
	}
    if (library) {
        cml_stream.put_string ("""add_library("${project_name_lower}" SHARED ${VALA_C})
    set_target_properties("${project_name_lower}" PROPERTIES
        VERSION "${${project_name}_VERSION}"
        SOVERSION "${soversion}"
    )
    target_link_libraries("${project_name_lower}" ${PROJECT_LDFLAGS} %s)
    add_definitions(${PROJECT_C_FLAGS})""".printf (rflags));
    }
    cml_stream.put_string ("""# Set common C-macros.
    add_definitions(-DPACKAGE_NAME="${project_name}")
    add_definitions(-DPACKAGE_VERSION="${${project_name}_VERSION}")
    if(project_root)
      add_definitions(-DGETTEXT_PACKAGE="${project_root}")
    else()
      add_definitions(-DGETTEXT_PACKAGE="${project_name_lower}")
    endif()
    add_definitions(-DPACKAGE_DATA_DIR="${install_prefix}${datadir}")
    add_definitions(-DPACKAGE_UI_DIR="${install_prefix}${uidir}")
    add_definitions(-DLOCALE_DIR="${install_prefix}${localedir}")
    add_definitions(-DPIXMAP_DIR="${install_prefix}${pixdir}")
    add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")
    """);
    if (!library) {
        cml_stream.put_string ("""add_executable("${project_name_lower}" ${VALA_C})
    target_link_libraries("${project_name_lower}"
      ${PROJECT_LDFLAGS}
      %s
    )
    add_definitions(
      ${PROJECT_C_FLAGS}
    )
    install(TARGETS ${project_name_lower} DESTINATION "${bindir}")""".printf (rflags));
    } else {
        cml_stream.put_string ("""install(TARGETS "${project_name_lower}" DESTINATION "${libdir}")
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.pc" DESTINATION "lib/pkgconfig")
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.h" DESTINATION "${includedir}")
    set(vapi_files "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.deps" "${CMAKE_CURRENT_BINARY_DIR}/${project_name_lower}.vapi")
    install(FILES ${vapi_files} DESTINATION "${VALA_VAPIDIR}")
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${project_name}-${${project_name}_VERSION}.gir" DESTINATION "${datarootdir}/gir-1.0")""");
    }

    cml_stream.put_string ("""# Install user interface files if used and copy them to build directory.
    set(uifiles_build)
    foreach(uifile ${uifiles})
      add_custom_command(
        OUTPUT
          "${CMAKE_CURRENT_BINARY_DIR}/${uifile}"
        COMMAND
          "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/${uifile}" "${CMAKE_CURRENT_BINARY_DIR}/${uifile}"
        DEPENDS
          "${CMAKE_CURRENT_SOURCE_DIR}/${uifile}"
        COMMENT ""
      )
      list(APPEND uifiles_build "${CMAKE_CURRENT_BINARY_DIR}/${uifile}")
      install(FILES ${uifile} DESTINATION "${uidir}")
    endforeach()
    add_custom_target("ui_copy_${project_name_lower}" DEPENDS ${uifiles_build})
    add_dependencies("${project_name_lower}" "ui_copy_${project_name_lower}")""");

    cml_stream.close();
    
if (library)
            {
                var str_deps = Path.build_path (Path.DIR_SEPARATOR_S,
                                       project.project_path,
                                       project.project_name+".deps.in");
                var file_stream = File.new_for_path (str_deps).replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
                var data_stream = new DataOutputStream (file_stream);
                data_stream.put_string ("@deps_requirements@\n");
                data_stream.close();
                
                var str_pc = Path.build_path (Path.DIR_SEPARATOR_S,
                                       project.project_path,
                                       project.project_name+".pc.in");
                file_stream = File.new_for_path (str_pc).replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
                data_stream = new DataOutputStream (file_stream);
                data_stream.put_string ("""prefix=@pc_prefix@
exec_prefix=@pc_exec_prefix@
libdir=@pc_libdir@
includedir=@pc_includedir@
datarootdir=@pc_datarootdir@
vapidir=@pc_vapidir@

Name: %s
Description: %s
Version: @pc_version@
Requires: @pc_requirements@
Libs: -L${libdir} -l%s
Cflags: -I${includedir}/""".printf (project.project_name, project.project_name, project.project_name));
                data_stream.close();
            }
           
            
    
        }catch (GLib.IOError e) {
            throw new BuildError.INITIALIZATION_FAILED (_("Could not read file: %s\n"), e.message);
        } catch (GLib.Error e) {
            throw new BuildError.INITIALIZATION_FAILED (_("Could not open file: %s\n"), e.message);
        }

        var strb_pkgs = new StringBuilder ("set(required_pkgs\n");
        foreach (var pkgmap in get_pkgmaps().values) {
            if (pkgmap.choice_pkg != null && !pkgmap.check)
                strb_pkgs.append (@"  \"$((pkgmap as PackageInfo))\"\n");
            else
                strb_pkgs.append (@"  \"$pkgmap\"\n");
        }
        strb_pkgs.append (")\n");

        var strb_files = new StringBuilder ("set(srcfiles\n");
        var strb_vapis = new StringBuilder ("set(vapifiles\n");
        foreach (var filepath in project.files) {
            var fname = project.get_relative_path (filepath);
            if (filepath.has_suffix (".vapi"))
                strb_vapis.append (@"  \"$fname\"\n");
            else
                strb_files.append (@"  \"$fname\"\n");
        }
        strb_files.append (")\n");
        strb_vapis.append (")\n");

        var strb_uis = new StringBuilder ("set(uifiles\n");
        foreach (var filepath in project.u_files)
            strb_uis.append (@"  \"$(project.get_relative_path (filepath))\"\n");
        strb_uis.append (")\n");

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
            // data_stream.put_string ("# Last change: %s\n".printf (time.format ("%F %T %z")));
            data_stream.put_string (@"set(project_name \"$(project.project_name)\")\n");
            data_stream.put_string (@"set($(project.project_name)_VERSION \"$(project.version_major).$(project.version_minor).$(project.version_patch)\")\n");
            if (library) {
			    data_stream.put_string ("set(soversion \"%d\")\n".printf (project.version_major));
			}
            data_stream.put_string (strb_pkgs.str);
            data_stream.put_string (strb_files.str);
            data_stream.put_string (strb_vapis.str);
            data_stream.put_string (strb_uis.str);

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

    public override bool configure (out int? exit_status = null) throws BuildError.INITIALIZATION_FAILED,
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
            throw new BuildError.CONFIGURATION_FAILED (_("configure command failed"));
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = get_exit (status);
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
        var cmdline = new string[] {"make", @"-j$(BuildSystem.threads)"};

        Pid? pid;
        int? pstdout, pstderr;
        if (!call_cmd (cmdline, out pid, true, out pstdout, out pstderr)) {
            build_finished();
            throw new BuildError.CONFIGURATION_FAILED (_("build command failed"));
        }

        var chn = new IOChannel.unix_new (pstdout);
        chn.set_buffer_size (1);
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
        chnerr.set_buffer_size (1);
        chnerr.add_watch (IOCondition.IN | IOCondition.HUP, (source, condition) => {
            bool ret;
            build_output (channel_output_read_line (source, condition, out ret));
            return ret;
        });

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

    public override bool check_existance() {
        var makefile = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                           buildpath,
                                                           "Makefile"));
        return makefile.query_exists();
    }

    public override bool clean (out int? exit_status = null)
                                        throws BuildError.CLEAN_FAILED {
        exit_status = null;
        // cleaned = false;
        clean_started();

        if (!check_existance()) {
            build_output (_("No data to clean.\n"));
            clean_finished();
            return true;
        }

        var cmdline = new string[] {"make", "clean"};

        Pid? pid;
        if (!call_cmd (cmdline, out pid)) {
            clean_finished();
            throw new BuildError.CLEAN_FAILED (_("clean command failed"));
        }

        int? exit = null;
        ChildWatch.add (pid, (intpid, status) => {
            exit = get_exit (status);
            Process.close_pid (intpid);
            builder_loop.quit();
        });

        builder_loop.run();
        exit_status = exit;
        // cleaned = true;
        clean_finished();
        return exit_status == 0;
    }

    public override bool distclean (out int? exit_status = null)
                                            throws BuildError.CLEAN_FAILED {
        exit_status = null;
        // distcleaned = false;
        distclean_started();
        project.enable_defines_all();

        if (!FileUtils.test (buildpath, FileTest.EXISTS)) {
            build_output (_("No data to clean.\n"));
            clean_finished();
            return true;
        }

        try {
            remove_recursively (buildpath, true, false);
            exit_status = 0;
        } catch (GLib.Error e) {
            exit_status = 1;
            var msg = _("distclean command failed: %s").printf (e.message);
            build_output (msg + "\n");
            throw new BuildError.CLEAN_FAILED (msg);
        }

        // distcleaned = true;
        distclean_finished();
        return exit_status == 0;
    }
}

// vim: set ai ts=4 sts=4 et sw=4
