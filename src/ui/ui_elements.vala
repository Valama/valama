/*
 * src/ui/ui_elements.vala
 * Copyright (C) 2012, 2013, Valama development team
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

/**
 * Provides an abstraction for all pluggable UI elements.
 *
 */
/*
 * Do not use an interface because we already have some precise definitions
 * (e.g. an instance field ui_connections).
 * Depencency interface is implented (update calls).
 */
public abstract class UiElement : Object{
    /**
     * Element name to identify elements easily.
     */
    protected string element_name;

    public Gtk.Widget widget;
    public Gdl.DockItem dock_item;

    /**
     * Share the project ({@link ValamaProject}) between all elements.
     */
    public static ValamaProject project { get; set; }

    /**
      * Update and generate this {@link UiElement}.
      *
      * This build method is not called directly by others. Instead
      * {@link update} is used (which calls all dependent build methods).
      */
    protected abstract void build();

    //private Thread<void*> t;
    /**
     * Call {@link build} methods from this and all dependent
     * {@link UiElement} class instances.
     *
     * Dependencies can be added with {@link add_deps}. They are invoked in
     * parallel with {@link GLib.Thread} instances.
     */
    public void update (ValamaProject? vproject=null) {
        if (vproject != null)
            project = vproject;
        /* Already start first update. */
        //t = new Thread<void*> (element_name, (ThreadFunc<void*>) build);
#if NOT_THREADED
        //t.join();
#endif
        update_deps();
    }

    /**
      * Queue of dependencies which have same priority (resolve in parallel).
      */
    private static Gee.PriorityQueue<UiElement> q = new Gee.PriorityQueue<UiElement>();
    /**
      * Queue of dependencies which have different priorities (resolve
      * sequencially).
      */
    //TODO: Not implemented.
    //private static Gee.PriorityQueue<UiElement> s_q = new Gee.PriorityQueue<UiElement>();

    /**
     * Add all dependencies to queue {@link q} and avoid duplicates.
     */
    private void add_deps() {
        if (!q.contains (this))
            q.add (this);
        foreach (UiElement ui_element in ui_connections)
            ui_element.add_deps();
    }

    /**
     * Dependencies between {@link UiElement} instances.
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
    /**
     * Add an existing {@link UiElement} to equitable dependencies.
     */
    public new void connect (UiElement element) {
        ui_connections.add (element);
    }
    /**
     * Remove an existing {@link UiElement} from equitable dependencies.
     */
    public new void disconnect (UiElement element) {
        ui_connections.remove (element);
    }
    //public void s_connect (UiElement element) {
    //    ui_connections.add (element);
    //}
    //public void s_disconnect (UiElement element) {
    //    ui_connections.remove (element);
    //}

    /**
     * Calculate order of dependencies then update everything in pool
     * {@link q}.
     */
    private void update_deps() {
        /* First of all mark all dependencies as dirty (add it to queue). */

        build();
        foreach (UiElement ui_element in ui_connections)
            ui_element.update();
        //    ui_element.add_deps();

        /* Then run all updates. */
        /*try {
            var tp = new ThreadPool<UiElement>.with_owned_data ((worker) => {worker.build();},
#if NOT_THREADED
                                                                0,
#else
                                                                q.size,
#endif
                                                                false);
            UiElement queue_element;
            while ((queue_element = q.poll()) != null)
                tp.add (queue_element);
            q.clear();
        } catch (GLib.ThreadError e) {
            errmsg (_("Could not start new thread: %s\n"), e.message);
        }*/
    }

    /* Abort all updates. */
    //TODO: Not implemented.
    //public void abort() {}
}

/**
 * Toplevel UiElement pool. This is only transitional until gdl...
 */
//FIXME: Replace this.
public class UiElementPool : ArrayList<UiElement> {}

// vim: set ai ts=4 sts=4 et sw=4
