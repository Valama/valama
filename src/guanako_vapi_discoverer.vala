using GLib;

namespace Guanako{

    public static string? discover_vapi_file(string needle_namespace){
        var directory = File.new_for_path ("/usr/share/vala-0.16/vapi");

        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null) {
            if (file_info.get_name().has_suffix(".vapi")){
                var file = File.new_for_path ("/usr/share/vala-0.16/vapi/" + file_info.get_name ());
                var dis = new DataInputStream (file.read ());
                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null)
                    if (line.contains("namespace " + needle_namespace + " "))
                        return file_info.get_name().substring(0, file_info.get_name().length - 5);
            }
        }
        return null;
    }

}

