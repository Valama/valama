
/*
  Unit:         Builder
  Purpose:      Provide abstract functionality for building a target
  Unit deps:    main_toolbar
*/

namespace Units {

  public class BuilderProvider : Unit {
    
    public enum BuilderState {
      NOT_COMPILED,
      COMPILED,
      COMPILING
    }
    
    public BuilderState state = BuilderState.NOT_COMPILED;
    
    public override void init() {
      // Track current target
      main_widget.main_toolbar.selected_target_changed.connect(()=>{
        update();
      });
      update();
    }


    private void update() {
      var current_target = main_widget.main_toolbar.selected_target;
    }
    
    public void build() {
    
    }
    public void rebuild() {
    
    }
    public void clean() {
    
    }
    
    public override void destroy() {
    }

 }

}
