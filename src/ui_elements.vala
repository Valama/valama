/**
 * src/ui_elements.vala
 * Copyright (C) 2012, Dominique Lasserre <lasserre.d@gmail.com>
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

/*
 * Provide an abstraction for all pluggable UI elements.
 * Do not use an interface because we already have some precise definitions
 * (e.g. an instance field ui_connections).
 * Depencency interface is implented (update calls).
 */
public abstract class UiElement {
    /* Element name to identify elements easily. */
    protected string element_name;

    /* Share the Valama project between all elements. */
    public static ValamaProject project { get; set; }

    /* Implement update for this single element in derived element class. */
    protected abstract void build();

    /*
     * Call the update method to update this single element and all (reverse)
     * dependencies.
     */
    private Thread<void*> t;
    public void update(ValamaProject? vproject=null) {
        if (vproject != null)
            project = vproject;
        /* Already start first update. */
        t = new Thread<void*> (element_name, (ThreadFunc<void*>) build);
        update_deps();
    }

    /* Queue of (reverse) dependencies to resolve in parallel. */
    private static Gee.PriorityQueue<UiElement> q = new Gee.PriorityQueue<UiElement>();
    /* Queue of (reverse) dependencies to resolve sequencially. */
    //TODO: Not implemented.
    //private static Gee.PriorityQueue<UiElement> s_q = new Gee.PriorityQueue<UiElement>();

    /* Add all dependencies to queue. */
    private void add_deps() {
        if (!q.contains (this))
            q.add (this);
        foreach (UiElement ui_element in ui_connections)
            ui_element.add_deps();
    }

    /*
     * Dependencies between elements.
     * Be careful to avoid circular dependencies and deadlocks.
     */
    /* Order is not interesting. These "dependencies" are equitable. */
    private ArrayList<UiElement> ui_connections = new ArrayList<UiElement>();
    /*
     * Order is important. These dependencies have to be called before this
     * element.
     */
    //TODO: Not implemented.
    //private ArrayList<UiElement> ui_dependencies;
    public void connect (UiElement element) {
        ui_connections.add (element);
    }
    public void disconnect (UiElement element) {
        ui_connections.remove (element);
    }
    //public void s_connect (UiElement element) {
    //    ui_connections.add (element);
    //}
    //public void s_disconnect (UiElement element) {
    //    ui_connections.remove (element);
    //}

    /* Calculate order of dependencies then update all. */
    private void update_deps() {
        /* First of all mark all dependencies as dirty (add it to queue). */
        foreach (UiElement ui_element in ui_connections)
            ui_element.add_deps();

        /* Then run all updates. */
        try {
            var tp = new ThreadPool<UiElement>.with_owned_data ((worker) => {worker.build();},
                                                                q.size,
                                                                false);
            UiElement queue_element;
            while ((queue_element = q.poll()) != null)
                tp.add (queue_element);
            q.clear();
        } catch (GLib.ThreadError e) {
            stderr.printf ("Could not start new thread: %s", e.message);
        }
    }

    /* Abort all updates. */
    //TODO: Not implemented.
    //public void abort() {}
}

/* Toplevel UiElement pool. This is only transitional until gdl... */
//FIXME: Replace this.
public class UiElementPool : ArrayList<UiElement> {}

// vim: set ai ts=4 sts=4 et sw=4
