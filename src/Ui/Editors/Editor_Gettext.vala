using Gtk;

namespace Ui {

  [GtkTemplate (ui = "/src/Ui/Editors/Editor_Gettext.glade")]
  private class EditorGettextTemplate : Box {
    [GtkChild]
    public Box box_settings;
    [GtkChild]
    public ScrolledWindow scrw_srcview;
    [GtkChild]
    public SourceView srcview;
    [GtkChild]
    public Viewport vp_sources;
    [GtkChild]
    public Viewport vp_gladeuis;
    [GtkChild]
    public ListBox list_languages;
    [GtkChild]
    public Entry ent_name;
    [GtkChild]
    public ToolButton btn_remove;
    [GtkChild]
    public ToolButton btn_add;
    [GtkChild]
    public Button btn_update;
  }

  public class EditorGettext : Editor {

    private EditorGettextTemplate template = new EditorGettextTemplate();

    public EditorGettext(Project.ProjectMemberGettext member, Ui.MainWidget main_widget) {
      this.main_widget = main_widget;
      this.member = member;
      title = "Gettext";

      // Show translation and gettext name, keep in sync
      template.ent_name.text = member.translation_name;
      template.ent_name.changed.connect (()=>{
        member.translation_name = template.ent_name.text;
        member.project.member_data_changed (this, member);
      });

      // Build treebox showing included source files
      var treebox = new FileTreeBox (true);
      var my_member = member as Project.ProjectMemberGettext;
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberValaSource))
          continue;
        var path = (m as Project.ProjectMemberValaSource).file.get_rel();
        treebox.add_file (path, m, m.id in my_member.included_sources);
      }
      treebox.file_checked.connect ((filename, data, checked)=>{
        var checked_member = data as Project.ProjectMemberValaSource;
        if (checked)
          my_member.included_sources.add (checked_member.id);
        else
          my_member.included_sources.remove (checked_member.id);
        main_widget.project.member_data_changed (this, my_member);
      });
      template.vp_sources.add (treebox.update());
      template.vp_sources.show_all();

      // Build treebox showing included gladeui files
      treebox = new FileTreeBox (true);
      foreach (Project.ProjectMember m in my_member.project.members) {
        if (!(m is Project.ProjectMemberGladeUi))
          continue;
        var path = (m as Project.ProjectMemberGladeUi).file.get_rel();
        treebox.add_file (path, m, m.id in my_member.included_gladeuis);
      }
      treebox.file_checked.connect ((filename, data, checked)=>{
        var checked_member = data as Project.ProjectMemberGladeUi;
        if (checked)
          my_member.included_gladeuis.add (checked_member.id);
        else
          my_member.included_gladeuis.remove (checked_member.id);
        main_widget.project.member_data_changed (this, my_member);
      });
      template.vp_gladeuis.add (treebox.update());
      template.vp_gladeuis.show_all();

      // Keep in sync
      member.project.member_added.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var path = (member as Project.ProjectMemberValaSource).file.get_rel();
          treebox.add_file (path, member, member.id in my_member.included_sources);
        }
      });
      member.project.member_removed.connect ((member)=>{
        if (member is Project.ProjectMemberValaSource) {
          var path = (member as Project.ProjectMemberValaSource).file.get_rel();
          treebox.remove_file (treebox.get_entry(path));
        }
      });

      // Show languages
      var settings_row = new Gtk.ListBoxRow();
      settings_row.set_data <bool> ("settings", true);
      settings_row.add (new Label ("Settings"));
      template.list_languages.add (settings_row);
      settings_row.show_all();

      foreach (var lang in member.languages) {
        add_language_entry (lang);
      }

      template.list_languages.row_selected.connect((row)=>{
        if (row == null)
          return;
        language_selected (row);
      });
      template.list_languages.select_row(settings_row);

      // Add / remove languages
      template.btn_remove.clicked.connect (()=>{
        // Remove language from list and member
        var row = template.list_languages.get_selected_row();
        var lang = row.get_data<string>("lang");
        template.list_languages.remove (row);
        member.languages.remove (lang);
        // Reset currently selected language to null!
        current_lang = null;
      });
      template.btn_add.clicked.connect (()=>{
        add_language_dialog();
      });

      // Update pot / po's
      template.btn_update.clicked.connect (()=>{
        var cmd_build = new StringBuilder();
        cmd_build.append ("/bin/sh -c \"");
        cmd_build.append ("xgettext --keyword=_ --escape --sort-output -o '" + member.potfile.get_abs() + "'");
        cmd_build.append(" -D " + File.new_for_path (member.project.filename).get_parent().get_path());
        foreach (var id in member.included_sources) {
          var valasource = member.project.getMemberFromId (id) as Project.ProjectMemberValaSource;
          cmd_build.append (" " + valasource.file.get_rel ());
        }
        foreach (var id in member.included_gladeuis) {
          var gladeui = member.project.getMemberFromId (id) as Project.ProjectMemberGladeUi;
          cmd_build.append (" " + gladeui.file.get_rel ());
        }
        //cmd_build.append("&& ");
        cmd_build.append("\"");
        // TODO:  intltool-extract --type=gettext/glade Editor_Gettext.glade
        main_widget.console_view.spawn_process (cmd_build.str);
      });

      main_widget.main_toolbar.selected_target_changed.connect(hook_save_on_compile);
      hook_save_on_compile();

      widget = template;
    }

    // Before compiling, save file (if it is part of the selected target)
    ulong hook = 0;
    Builder.Builder hooked_builder = null;
    private void hook_save_on_compile() {
      if (hooked_builder != null) // track selected target
        hooked_builder.disconnect (hook);
      var builder = main_widget.main_toolbar.selected_target.builder;
      hook = builder.state_changed.connect (()=>{
        var my_member = member as Project.ProjectMemberGettext;
        if (current_lang != null)
          if (builder.state == Builder.BuilderState.COMPILING)
            if (main_widget.main_toolbar.selected_target.included_gettexts.contains (my_member.id))
              save_language (current_lang);
      });
      hooked_builder = builder;
    }

    private void add_language_entry (string lang) {
      var my_member = member as Project.ProjectMemberGettext;

      // Add list entry
      var row = new Gtk.ListBoxRow();
      row.set_data <string> ("lang", lang);
      row.set_data <bool> ("settings", false);
      row.add (new Label(lang));
      template.list_languages.add (row);
      row.show_all();
    }

    string? current_lang = null;
    ulong change_hook = 0;
    private void language_selected (ListBoxRow row) {
      if (row == null)
        return;
      if (row.get_data<bool>("settings")) {
        template.box_settings.visible = true;
        template.btn_remove.sensitive = false;
        template.scrw_srcview.visible = false;
      } else {
        template.box_settings.visible = false;
        template.btn_remove.sensitive = true;
        template.scrw_srcview.visible = true;

        var my_member = member as Project.ProjectMemberGettext;

        // When switching, save
        if (current_lang != null)
          save_language (current_lang);
        current_lang = row.get_data<string>("lang");

        // Load translation
        var file = my_member.get_po_file (current_lang);
        string content;
        FileUtils.get_contents (file.get_abs(), out content);

        if (change_hook != 0)
          template.srcview.buffer.disconnect (change_hook);
        template.srcview.buffer.text = content;

        // When content is changed, invalidate all targets depending on this file
        change_hook = template.srcview.buffer.changed.connect (()=>{
          foreach (var pmember in my_member.project.members) {
            if (pmember is Project.ProjectMemberTarget) {
              var target = pmember as Project.ProjectMemberTarget;
              if (target.included_gettexts.contains (my_member.id))
                target.builder.state = Builder.BuilderState.NOT_COMPILED;
            }
          }
        });


      }
    }

    private void save_language (string lang) {
      var my_member = member as Project.ProjectMemberGettext;
      var file = File.new_for_path(my_member.get_po_file (current_lang).get_abs());
      var fos = file.replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
      var dos = new DataOutputStream (fos);
      dos.put_string (template.srcview.buffer.text);
      dos.flush();
      dos.close();
    }

    private void add_language_dialog() {
      var my_member = member as Project.ProjectMemberGettext;
      var dlg = new Dialog.with_buttons("Add language", main_widget.window, DialogFlags.MODAL);
      var btn_ok = dlg.add_button ("OK", ResponseType.OK);
      btn_ok.sensitive = false;
      dlg.add_button ("Cancel", ResponseType.CANCEL);

      // Add entry for new language
      var entry = new Entry();
      entry.changed.connect (()=>{
        btn_ok.sensitive = entry.text.length != 0 && !(entry.text in my_member.languages);
      });
      entry.show();
      dlg.get_content_area().add(entry);

      // If OK selected, add language
      if (dlg.run() == ResponseType.OK) {
        my_member.languages.add (entry.text);
        my_member.project.member_data_changed (this, my_member);
        add_language_entry (entry.text);

        // Initialize po file
        var cmd_build = new StringBuilder();
        cmd_build.append ("/bin/sh -c \"");
        cmd_build.append ("msginit -l " + entry.text + " -o '" + my_member.get_po_file(entry.text).get_abs() + "' -i " + my_member.potfile.get_abs());
        cmd_build.append ("\"");
        main_widget.console_view.spawn_process (cmd_build.str);
      }
      dlg.destroy();
    }

    public override void load_internal (Xml.TextWriter writer) {

    }
    public override void save_internal (Xml.TextWriter writer) {
      if (current_lang != null)
        save_language (current_lang);
    }
    internal override void destroy_internal() {
    
    }
  }

}

