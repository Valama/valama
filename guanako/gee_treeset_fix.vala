/*
 * guanako/gee_treeset_fix.vala
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

// Fixes a memory leak (copied from upstream fix)
public class FixedTreeSet<G> : Gee.TreeSet<G> {
#if GEE_0_8
    public FixedTreeSet (CompareDataFunc? comp_func = null) {
#elif GEE_1_0
    public FixedTreeSet (CompareFunc? comp_func = null) {
#endif
        base (comp_func);
    }

    ~FixedTreeSet() {
        clear();
    }
}