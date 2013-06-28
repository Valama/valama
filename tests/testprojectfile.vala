/*
 * tests/testprofile.vala
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

public class TestProjectfile : TestCase {
    public TestProjectfile() {
        base ("TestProjectfile");
        add_test ("paths", test_paths);
        add_test ("version", test_version);
    }

    public override void set_up() {}
    public override void tear_down() {}

    //TODO: Compute project files on runtime?
    public void test_paths() {
        ProjectFile p = null;
        try {
            //NOTE: Execution in tests/ directory is mandatory.
            p = new ProjectFile ("projectfile/pathtest.vlp");
        } catch (LoadingError e) {
            error (_("LoadingError: %s\n"), e.message);
        }
        assert (p as ProjectFile != null);

        assert (p.get_absolute_path ("/foo/bar/foo") == "/foo/bar/foo");
        assert (p.get_absolute_path ("foo/bar/foo") == Path.build_path (Path.DIR_SEPARATOR_S,
                                                                        Environment.get_current_dir(),
                                                                        "projectfile", "foo", "bar", "foo"));
        assert (p.get_relative_path ("/foo/bar/foo") == "/foo/bar/foo");
        assert (p.get_relative_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                      Environment.get_current_dir(),
                                                      "projectfile", "foo", "bar", "foo")) == "foo/bar/foo");
        assert (p.get_relative_path (Path.build_path (Path.DIR_SEPARATOR_S,
                                                      Environment.get_current_dir(),
                                                      "projectfile")) == "");
    }

    public void test_version() {
        ProjectFile p_version_none = null;
        try {
            //NOTE: Execution in tests/ directory is mandatory.
            p_version_none = new ProjectFile ("projectfile/version_none.vlp");
        } catch (LoadingError e) {
        }
        assert (p_version_none as ProjectFile == null);

        ProjectFile p_version_low = null;
        try {
            p_version_low = new ProjectFile ("projectfile/version_low.vlp");
        } catch (LoadingError e) {
        }
        assert (p_version_low as ProjectFile == null);

        ProjectFile p_version_exact = null;
        try {
            p_version_exact = new ProjectFile ("projectfile/version_exact.vlp");
        } catch (LoadingError e) {
            error (_("LoadingError: %s\n"), e.message);
        }
        assert (p_version_exact as ProjectFile != null);

        ProjectFile p_version_high = null;
        try {
            p_version_high = new ProjectFile ("projectfile/version_high.vlp");
        } catch (LoadingError e) {
            error (_("LoadingError: %s\n"), e.message);
        }
        assert (p_version_high as ProjectFile != null);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
