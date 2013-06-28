/*
 * tests/testmain.vala
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

void main (string[] args) {
    Test.init (ref args);

    TestSuite.get_root().add_suite (new TestCompVersion().get_suite());
    TestSuite.get_root().add_suite (new TestPathSplit().get_suite());
    TestSuite.get_root().add_suite (new TestProjectfile().get_suite());

    Test.run();
}

// vim: set ai ts=4 sts=4 et sw=4
