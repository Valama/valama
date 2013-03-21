set(project_name "Guanako")
set(Guanako_VERSION "1.0")
set(soversion "1")
set(required_pkgs
"gobject-2.0"
"glib-2.0"
"gio-2.0"
"gee-0.8"
"gee-1.0"
"libvala-0.18"
"libvala-0.20"
"libxml-2.0"
)
set(srcfiles
"gee_treeset_fix.vala"
"guanako_auto_indent.vala"
"guanako_helpers.vala"
"guanako_iterators.vala"
"guanako.vala"
"guanako_vapi_discoverer.vala"
"guanako_frankenstein.vala"
"scanner/valascanner.vala"
"scanner/valaparser.vala"
"stylecheck.vala"
)
set(vapifiles
"config.vapi"
)
