using GLib;

namespace MyNS {
    public class Lib : Object {

        public signal void sample_signal(int a, int b);
	
        public int calc (int a, int b) {
            sample_signal (a, b);
            return a + b;
        }
    }
}
