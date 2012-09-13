/**
 * src/ui_project_dialog.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
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
 
using Gtk;
 
public void ui_project_dialog(valama_project project){
        var dlg = new Dialog.with_buttons("Project settings", window_main, DialogFlags.MODAL, Stock.OK, ResponseType.ACCEPT);
        dlg.set_size_request(400, 200);

        var box_main = new Box(Orientation.VERTICAL, 0);

        var frame_project = new Frame("Project");

            var box_project = new Box(Orientation.VERTICAL, 0);
            box_project.pack_start(new Label("Name"), false, false);
            var ent_proj_name = new Entry();
            ent_proj_name.text = project.project_name;
            ent_proj_name.changed.connect(()=>{ project.project_name = ent_proj_name.text; });
            box_project.pack_start(ent_proj_name, false, false);
            frame_project.add(box_project);

        box_main.pack_start(frame_project, true, true);
        box_main.show_all();

        dlg.get_content_area().pack_start(box_main);
        dlg.run();
        dlg.destroy();
} 
