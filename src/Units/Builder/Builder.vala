
/*
  Unit:         Builder
  Purpose:      Provide abstract functionality for building a target
  Unit deps:    none
*/

namespace Units {

  public class Builder : Unit {
    
    public enum BuilderState {
      IDLE,
      COMPILING
    }
    
    public BuilderState state = BuilderState.IDLE;
    
    public override void init() {
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
