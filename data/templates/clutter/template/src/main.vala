using GLib;
using Clutter;

static Stage stage;
static Rectangle r;

static void main (string[] args) {
    Clutter.init (ref args);

    stage = new Stage();

    r = new Rectangle();
    r.width = 100;
    r.height = 100;
    r.color = Color.from_string ("Green");
    r.reactive = true;
    r.button_press_event.connect (() => {
        animate_it();
        return false;
    });

    stage.add_child (r);
    stage.show();

    animate_it();

    Clutter.main();
}

static void animate_it() {
    r.x = 0;
    r.y = 0;
    r.animate (AnimationMode.EASE_OUT_BOUNCE, 3000,
               x: stage.width - r.width,
               y: stage.height - r.height,
               rotation_angle_z: r.rotation_angle_z + 90);
}
