/*
 * tests/testpathsplit.vala
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

public class TestPathSplit : TestCase {
    public TestPathSplit() {
        base ("TestPathSplit");
        add_test ("standard", test_normal);
        add_test ("relative_paths", test_relative_paths);
        add_test ("relative_paths_special", test_relative_paths_special);
        add_test ("utf8_paths", test_utf8);
        add_test ("bytecharindex", test_bytetoindex);
    }

    public override void set_up() {}
    public override void tear_down() {}

    public void test_normal() {
        string[] splitpaths;

        var baseparts = new string[] {"/", "usr", "share", "valama", "templates"};
        splitpaths = split_path ("/usr/share/valama/templates", true, true);
        assert (baseparts.length == splitpaths.length);
        for (int i = 0; i < baseparts.length; ++i)
            assert (splitpaths[i] == baseparts[i]);
        var baseparts_d = baseparts;
        splitpaths = split_path ("/usr/share/valama/templates/", true, true);
        assert (baseparts_d.length == splitpaths.length);
        for (int i = 0; i < baseparts_d.length + 1; ++i)
            assert (splitpaths[i] == baseparts_d[i]);

        var baseparts_noroot = new string[] {"usr", "share", "valama", "templates"};
        splitpaths = split_path ("/usr/share/valama/templates", true, false);
        assert (baseparts_noroot.length == splitpaths.length);
        for (int i = 0; i < baseparts_noroot.length; ++i)
            assert (splitpaths[i] == baseparts_noroot[i]);

        var absoluteparts = new string[] {"/", "/usr", "/usr/share", "/usr/share/valama", "/usr/share/valama/templates"};
        splitpaths = split_path ("/usr/share/valama/templates", false, true);
        assert (absoluteparts.length == splitpaths.length);
        for (int i = 0; i < absoluteparts.length; ++i)
            assert (splitpaths[i] == absoluteparts[i]);

        var absoluteparts_noroot = new string[] {"usr", "usr/share", "usr/share/valama", "usr/share/valama/templates"};
        splitpaths = split_path ("/usr/share/valama/templates", false, false);
        assert (absoluteparts_noroot.length == splitpaths.length);
        for (int i = 0; i < absoluteparts_noroot.length; ++i)
            assert (splitpaths[i] == absoluteparts_noroot[i]);
    }

    public void test_relative_paths() {
        string[] splitpaths;

        var baseparts = new string[] {"usr", "share", "valama", "templates"};
        splitpaths = split_path ("usr/share/valama/templates", true, true);
        assert (baseparts.length == splitpaths.length);
        for (int i = 0; i < baseparts.length; ++i)
            assert (splitpaths[i] == baseparts[i]);

        var baseparts_noroot = new string[] {"usr", "share", "valama", "templates"};
        splitpaths = split_path ("usr/share/valama/templates", true, false);
        assert (baseparts_noroot.length == splitpaths.length);
        for (int i = 0; i < baseparts_noroot.length; ++i)
            assert (splitpaths[i] == baseparts_noroot[i]);

        var absoluteparts = new string[] {"usr", "usr/share", "usr/share/valama", "usr/share/valama/templates"};
        splitpaths = split_path ("usr/share/valama/templates", false, true);
        assert (absoluteparts.length == splitpaths.length);
        for (int i = 0; i < absoluteparts.length; ++i)
            assert (splitpaths[i] == absoluteparts[i]);

        var absoluteparts_noroot = new string[] {"usr", "usr/share", "usr/share/valama", "usr/share/valama/templates"};
        splitpaths = split_path ("usr/share/valama/templates", false, false);
        assert (absoluteparts_noroot.length == splitpaths.length);
        for (int i = 0; i < absoluteparts_noroot.length; ++i)
            assert (splitpaths[i] == absoluteparts_noroot[i]);
    }

    public void test_relative_paths_special() {
        assert (split_path (".", true, true).length == 0);
        assert (split_path (".", true, false).length == 0);
        assert (split_path (".", false, true).length == 0);
        assert (split_path (".", false, false).length == 0);

        assert (split_path ("", true, true).length == 0);
        assert (split_path ("", true, false).length == 0);
        assert (split_path ("", false, true).length == 0);
        assert (split_path ("", false, false).length == 0);
    }

    public void test_utf8() {
        var baseparts = new string[] {"/", "𤭢水は方円の器に従い", "asdf", "人は善悪の友による。"};
        var splitpaths = split_path ("/𤭢水は方円の器に従い/asdf/人は善悪の友による。", true, true);
        assert (baseparts.length == splitpaths.length);
        for (int i = 0; i < baseparts.length; ++i)
            assert (splitpaths[i] == baseparts[i]);
    }

    public void test_bytetoindex() {
        var mbytestr = "楽あれば苦あり。";  // 3 byte characters
        for (var i = 0; i < mbytestr.length; ++i)
            assert (byte_index_to_character_index (mbytestr, i, true) == ((i%3 == 0) ? i/3 : -1));
    }
}

// vim: set ai ts=4 sts=4 et sw=4
