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
 * Dependency interface is implemented (update calls).
 */
public abstract class UiElement : Object{
    /**
     * Possibility to lock gdl items (lock and hide grip).
     */
    protected bool locking;

    /**
     * Containing {@link Gtk.Widget}.
     */
    public Gtk.Widget widget;
    /**
     * Associated {@link Gdl.DockItem}.
     */
    public Gdl.DockItem? dock_item { get; set; default = null; }

    private bool? _visible = null;
    /**
     * Visibility of {@link dock_item}.
     */
    public bool? visible {
        get {
            return _visible;
        }
        private set {
            if (_visible != value) {
                _visible = value;
                visible_changed (_visible);
            }
        }
    }

    /**
     * Indicate if UI is initialized.
     */
    private static bool initialized = false;

    /**
     * Last opened {@link Gdl.DockItem} ({@link UiElement}).
     */
    private static Gdl.DockItem? latest_item = null;
    /**
     * Saved {@link Gdl.DockItemBehavior} after hiding/locking.
     */
    private Gdl.DockItemBehavior? saved_behavior;

    /**
     * Emit when visibility of {@link dock_item} has changed (either iconified
     * or closed).
     */
    public signal void visible_changed (bool status);

    /**
     * Status of dock_item. `true` if shown, `false` if hidden and `null` if
     * undefined.
     */
    private bool? show;

    /**
     * Indicate if dock_item is/should be hidden cause of it's {@link IdeModes}.
     */
    private bool modehide = false;

    /**
     * Emit to show search.
     *
     * @param show `true` to show, `false` to hide.
     */
    public signal void show_element (bool show);


    /**
     * Share the project ({@link ValamaProject}) between all elements.
     */
    public static ValamaProject project { get; set; }

    /**
     * Connect locking and unlocking signals.
     */
    public UiElement() {
        if (widget_main is Object) {
            widget_main.lock_items.connect (lock_item);
            widget_main.unlock_items.connect (unlock_item);
            widget_main.initialized.connect (() => {
                initialized = true;
            });
        } else
            error_msg (_("Could not initialize locking signals.\n"));
        locking = true;
        saved_behavior = null;
        show = null;

        this.notify["dock-item"].connect (() => {
            if (dock_item != null) {
                latest_item = dock_item;
                saved_behavior = null;
                visible = dock_item.visible;
                dock_item.notify["visible"].connect (() => {
                    visible = dock_item.visible;
                });
                dock_item.notify["master"].connect (() => {
                    if (dock_item.master != null)
                        dock_item.master.layout_changed.connect (() => {
#if !GDL_LESS_3_5_5
                            show = !dock_item.is_closed();
#else
                            show = ((dock_item.flags & Gdl.DockObjectFlags.ATTACHED) != 0);
#endif
                        });
                });
            }
        });

        this.visible_changed.connect ((status) => {
            show = status;
            show_element (status);
        });

        this.show_element.connect ((show) => {
            if (this.show == null || show != this.show) {
                this.show = show;
                if (show) {
                    modehide = true;
#if !GDL_LESS_3_5_5
                    dock_item.show_item();
#else
                    /*
                     * TODO: Avoid latest_item and instead use solution with
                     *       focussed element. Perhaps use Dock.toplevel_docks
                     *       or Dock.dock_objects.
                     */
                    if (dock_item != latest_item)
                        dock_item.dock_to (latest_item, Gdl.DockPlacement.CENTER, -1);
                    else
                        dock_item.show_item();
#endif
                    widget_main.focus_dock_item (dock_item);
                    on_element_show();
                } else {
// #if !GDL_LESS_3_5_5
//                     /* Hide also iconified item by making it visible first. */
//                     if (dock_item.is_iconified())
//                         dock_item.show_item();
// #endif
                    modehide = false;
                    on_element_hide();
                    dock_item.hide_item();
                }
            }
        });
    }

    /**
     * Run after show and focus {@link dock_item}.
     */
    protected virtual void on_element_show() {}

    /**
     * Run after hide {@link dock_item}.
     */
    protected virtual void on_element_hide() {}

    /**
     * Hide dock item grip and lock it.
     */
    private void lock_item() {
        if (!locking || dock_item == null || saved_behavior != null)
            return;
        saved_behavior = dock_item.behavior;
#if GDL_3_8_2
        dock_item.hide_grip();
#else
        /* Work arround gdl bug #515755 to not hide dockbar properly. */
        dock_item.behavior = Gdl.DockItemBehavior.NO_GRIP;
        dock_item.forall_internal (true, (child) => {
            if (child is Gdl.DockItemGrip)
                child.hide();
        });
#endif
    }

    /**
     * Show dock item grip and unlock it.
     */
    private void unlock_item() {
        if (!locking || dock_item == null)
            return;
        if (saved_behavior != null)
            dock_item.behavior = saved_behavior;
        saved_behavior = null;
#if GDL_3_8_2
        dock_item.show_grip();
#else
        /* See note above. */
        dock_item.forall_internal (true, (child) => {
            if (child is Gdl.DockItemGrip)
                child.show();
        });
#endif
    }

    /**
     * Query element name to identify class object.
     *
     * @return Return name.
     */
    public inline virtual string get_name() {
        return this.get_type().name();
    }

    /**
     * Show item in some {@link IdeModes} modes.
     */
    public void mode_to_show (IdeModes mode) {
        project.notify["idemode"].connect(() => {
            if (dock_item != null) {
                if ((project.idemode & mode) != 0) {
                    if (modehide) {
#if !GDL_LESS_3_5_5
                        if (initialized) {
                            dock_item.show_item();
                            dock_item.show_all();
                        }
#else
                        if (initialized && (latest_item != dock_item) &&
                                    ((dock_item.flags & Gdl.DockObjectFlags.ATTACHED) == 0))
                            dock_item.dock_to (latest_item, Gdl.DockPlacement.CENTER, -1);
#endif
                    }
                } else
                    dock_item.hide_item();
            }
        });
    }

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
        //t = new Thread<void*> (get_name(), (ThreadFunc<void*>) build);
        //t.join();
        update_deps();
    }

    /**
      * Queue of dependencies which have same priority (resolve in parallel).
      */
    private static Gee.PriorityQueue<UiElement> q = new Gee.PriorityQueue<UiElement>();
    /**
      * Queue of dependencies which have different priorities (resolve
      * sequentially).
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
                                                                q.size,
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

// vim: set ai ts=4 sts=4 et sw=4
