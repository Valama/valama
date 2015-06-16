set(project_name "Guanako")
set(Guanako_VERSION "1.0")
set(soversion "1")
set(required_pkgs
  "config {nocheck,nolink}"
  "gobject-2.0"
  "glib-2.0"
  "gio-2.0"
  "gee-0.8 >= 0.10.5"
  "libvala-0.20"
  "libvala-0.22"
  "libvala-0.24"
  "libvala-0.26"
  "libvala-0.28"
  "libvala-0.30"
  "libxml-2.0"
  "posix {nocheck,nolink}"
)
set(srcfiles
  "guanako.vala"
  "guanako_auto_indent.vala"
  "guanako_frankenstein.vala"
  "guanako_helpers.vala"
  "guanako_iterators.vala"
  "guanako_refactoring.vala"
  "guanako_vapi_discoverer.vala"
  "reporter.vala"
  "scanner/valascanner.vala"
  "scanner/valaparser.vala"
)
set(vapifiles
  "config.vapi"
)
