set(project_name "Guanako")
set(Guanako_VERSION "1.0")
set(soversion "1")
set(required_pkgs
"gobject-2.0"
"glib-2.0"
"gio-2.0"
"gee-0.8"
"libvala-0.18"
"libvala-0.20"
"libvala-0.22"
"libxml-2.0"
"posix {nocheck,nolink}"
)
set(srcfiles
"guanako_auto_indent.vala"
"guanako_helpers.vala"
"guanako_iterators.vala"
"guanako.vala"
"guanako_vapi_discoverer.vala"
"guanako_frankenstein.vala"
"reporter.vala"
"scanner/valascanner.vala"
"scanner/valaparser.vala"
)
set(vapifiles
"config.vapi"
)
