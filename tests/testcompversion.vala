/*
 * tests/testcompversion.vala
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

public class TestCompVersion : TestCase {
    public TestCompVersion() {
        base ("TestCompVersion");
        add_test ("standard", test_normal);
        add_test ("epoch", test_epoch);
    }

    public override void set_up() {}
    public override void tear_down() {}

    public void test_normal() {
        assert (comp_version ("14", "3") == 1);
        assert (comp_version ("14", "3.5") == 1);
        assert (comp_version ("14", "3.9.8") == 1);
        assert (comp_version ("14.1", "3.5") == 1);

        assert (comp_version ("3", "14") == -1);
        assert (comp_version ("3.5", "14") == -1);
        assert (comp_version ("3.9.8", "14") == -1);
        assert (comp_version ("3.5", "14.1") == -1);

        assert (comp_version ("4.1.2", "4.1.3") == -1);
        assert (comp_version ("4.10.2", "4.2.0") == 1);
        assert (comp_version ("4.1.2.3.6.4.12", "4.1.2.3.6.4.3") == 1);

        assert (comp_version ("4.1.2.3.6.4.2", "4.1.2.3.6.4.2") == 0);
        assert (comp_version ("4", "4") == 0);
    }

    public void test_epoch() {
        assert (comp_version ("1:3.0.0", "4.0") == 1);
        assert (comp_version ("1:3.0.0", "3.0.0") == 1);
        assert (comp_version ("1:3.0.0", "3.0.1") == 1);

        assert (comp_version ("1:3.0.0", "2:2.0") == -1);
        assert (comp_version ("1:3.0.0", "1:3.0.1") == -1);
        assert (comp_version ("1:3.0.0", "1:3.1") == -1);

        assert (comp_version ("15:3.0.0", "2:6.1") == 1);

        assert (comp_version ("1:3", "1:3") == 0);
    }
}

// vim: set ai ts=4 sts=4 et sw=4
