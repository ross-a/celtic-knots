package knots_test


import "core:fmt"
import "core:mem"
import "core:math"
import "core:strings"
import "core:testing"
import "vendor:raylib"
import knots "../"

main :: proc() {
  // note: raylib using ucrt.lib (dynamic libc) AND odin using libucrt.lib (static libc)
  // if you run odin test .. there is link with "something_testing.obj" which will cause conflict between the 2 ucrt libs
  // TODO: there is no simple easy fix for this yet? when I figure something out maybe remove this
  // or just don't use "core:testing" and "vendor:raylib" together
  // removed...   :test test_knots :cmpflag -show-debug-messages
  test_knots(nil)
}

draw_grid :: proc(w, h: i32, values: ^knots.Values) {
  using raylib

  for y in 0..<values.grid.y {
    for x in 0..<values.grid.x {
      //DrawRectangleLines(x * values.grid_spacing + values.margin.x, y * values.grid_spacing + values.margin.y, values.grid_spacing + 1, values.grid_spacing + 1, BLACK)
    }
  }
  // primary dots
  for y in 0..=values.grid.y {
    for x in 0..=values.grid.x {
      DrawCircle(x * values.grid_spacing + values.margin.x, y * values.grid_spacing + values.margin.y, 4, RED)
    }
  }
  // secondary dots
  for y in 0..<values.grid.y {
    for x in 0..<values.grid.x {
      xx : f32 = (f32(x)+0.5) * f32(values.grid_spacing) + f32(values.margin.x)
      yy : f32 = (f32(y)+0.5) * f32(values.grid_spacing) + f32(values.margin.y)
      DrawCircle(i32(xx), i32(yy), 4, GRAY)      
    }
  }
}

draw_bounds :: proc(w, h: i32, values: ^knots.Values) {
  using raylib

  knots.scan_for_short_and_long_arcs(values)  

  for y in 0..<values.grid.y*2 {
    for x in 0..<values.grid.x*2 {
      c := values.cells[y * (values.grid.x*2) + x]

      // center of cell
      c.xx = (f32(c.x)+0.5) * f32(values.grid_spacing)/2 + f32(values.margin.x)
      c.yy = (f32(c.y)+0.5) * f32(values.grid_spacing)/2 + f32(values.margin.y)
      
      xl := i32(c.xx - f32(values.grid_spacing)/4)
      yu := i32(c.yy - f32(values.grid_spacing)/4)
      xr := i32(c.xx + f32(values.grid_spacing)/4)
      yb := i32(c.yy + f32(values.grid_spacing)/4)

      if c.bn {
        DrawLine(xl, yu, xr, yu, BLACK)
      }
      if c.bs {
        DrawLine(xl, yb, xr, yb, BLACK)
      }
      if c.be {
        DrawLine(xr, yu, xr, yb, BLACK)
      }
      if c.bw {
        DrawLine(xl, yu, xl, yb, BLACK)
      }
    }
  }
}

draw_knot :: proc(values: ^knots.Values) {
  using raylib
  using knots

  knot_paths : [dynamic]KnotPath; defer delete(knot_paths)
  get_knot(values, &knot_paths)
  // TODO: don't get_knot everytime
  
  colr := BLACK
  //if false {      // TODO: put cell in knot_path??
  //  if c.type == u16(CellType.DIAGONAL) {
  //    colr = GRAY
  //  } else if c.type == u16(CellType.CORNER) {
  //    colr = RED
  //  } else if c.type == u16(CellType.ELBOW) {
  //    colr = GREEN
  //  } else if c.type == u16(CellType.SHORT_ARC) {
  //    colr = BLACK
  //  } else if c.type == u16(CellType.LONG_ARC) {
  //    colr = raylib.BEIGE
  //  }
  //  //DrawSplineLinear(path, i32(path_pts), 1, colr)
  //}

  for k in knot_paths {
    DrawTriangleStrip(k.path, i32(k.path_pts), colr)
    free(k.path)
  }
  
  // test elbox control points
  //if c.type == u16(CellType.LONG_ARC) {
  //  DrawCircle(i32(xx + pma.x * f32(values.grid_spacing)/2), i32(yy + pma.y * f32(values.grid_spacing)/2), 2, RED)
  //  DrawCircle(i32(xx + pma.z * f32(values.grid_spacing)/2), i32(yy + pma.w * f32(values.grid_spacing)/2), 2, GREEN)
  //  DrawCircle(i32(xx + pmb.x * f32(values.grid_spacing)/2), i32(yy + pmb.y * f32(values.grid_spacing)/2), 2, BLACK)
  //  DrawCircle(i32(xx + pmb.z * f32(values.grid_spacing)/2), i32(yy + pmb.w * f32(values.grid_spacing)/2), 2, DARKGREEN)
  //}
}

draw_menu :: proc(w, h: i32, values: ^knots.Values) {
  using raylib
  using knots

  if !values.show_menu {
    values.show_menu = GuiButton(Rectangle{f32(w) - 40, 13, 18, 18}, "_")
  } else {
    panel := GuiPanel(Rectangle{f32(w) - 210, 10, 190, 430}, "")
    values.show_menu = !GuiButton(Rectangle{f32(w) - 40, 13, 18, 18}, "_")    
    tmp_x := f32(values.grid.x)
    tmp_y := f32(values.grid.y)
    GuiSlider(Rectangle{f32(w) - 185, 40, 160, 20}, "x", "", &tmp_x, 1, 120)
    str := fmt.tprintf("%v", i32(tmp_x))
    cstr := strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 40, 160, 20}, cstr, 10, false)
    delete(cstr)
    GuiSlider(Rectangle{f32(w) - 185, 65, 160, 20}, "y", "", &tmp_y, 1, 20)
    str = fmt.tprintf("%v", i32(tmp_y))
    cstr = strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 65, 160, 20}, cstr, 10, false)
    delete(cstr)

    values.grid.x = i32(tmp_x)
    values.grid.y = i32(tmp_y)
    if (values.grid.y != values.prev_grid.y) || (values.grid.x != values.prev_grid.x) {
      clean_breaks(values)
      alloc_breaks(values)
      random_break_spots(values)
    }
    values.prev_grid = values.grid
    
    tmp_spacing := f32(values.grid_spacing)
    GuiSlider(Rectangle{f32(w) - 185, 90, 160, 20}, "spc", "", &tmp_spacing, 8, 120)
    values.grid_spacing = i32(tmp_spacing)
    str = fmt.tprintf("%v", i32(tmp_spacing))
    cstr = strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 90, 160, 20}, cstr, 10, false)
    delete(cstr)

    tmp_thickness := values.thickness * 100
    GuiSlider(Rectangle{f32(w) - 185, 115, 160, 20}, "thk", "", &tmp_thickness, 0, 100)
    if (values.thickness * 100) != tmp_thickness {
      clear(&values.cells)
    }
    values.thickness = tmp_thickness / 100
    str = fmt.tprintf("%v", values.thickness)
    cstr = strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 115, 160, 20}, cstr, 10, false)
    delete(cstr)


    tmp_gap := values.gap * 100
    GuiSlider(Rectangle{f32(w) - 185, 140, 160, 20}, "gap", "", &tmp_gap, 0, 50)
    if (values.gap * 100) != tmp_gap {
      clear(&values.cells)
    }
    values.gap = tmp_gap / 100
    str = fmt.tprintf("%v", values.gap)
    cstr = strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 140, 160, 20}, cstr, 10, false)
    delete(cstr)


    if GuiToggle(Rectangle{f32(w) - 185, 165, 160, 20}, "border & grid", &values.show_breaks) > 0 {
      values.show_breaks = !values.show_breaks
    }

    tmp_bpercent := values.breaks_percent * 100
    GuiSlider(Rectangle{f32(w) - 185, 190, 160, 20}, "b %", "", &tmp_bpercent, 0, 100)
    if (values.breaks_percent * 100) != tmp_bpercent {
      clean_breaks(values)
      alloc_breaks(values)
      random_break_spots(values)
    }
    values.breaks_percent = tmp_bpercent / 100
    str = fmt.tprintf("%v", values.breaks_percent)
    cstr = strings.clone_to_cstring(str)
    GuiTextBox(Rectangle{f32(w) - 185, 190, 160, 20}, cstr, 10, false)
    delete(cstr)

    @static dropdown_toggle := false
    
    if !dropdown_toggle { // controls to draw "under" the dropdown below
      GuiToggle(Rectangle{f32(w) - 185, 240, 160, 20}, "ringify", &values.ringify)
      tmp_border_x := values.border_x
      GuiToggle(Rectangle{f32(w) - 185, 265, 160, 20}, "border x", &tmp_border_x)
      if tmp_border_x != values.border_x {
        values.border_x = tmp_border_x
        clean_breaks(values)
        alloc_breaks(values)
        random_break_spots(values)
      }
      tmp_border_y := values.border_y
      GuiToggle(Rectangle{f32(w) - 185, 290, 160, 20}, "border y", &tmp_border_y)
      if tmp_border_y != values.border_y {
        values.border_y = tmp_border_y
        clean_breaks(values)
        alloc_breaks(values)
        random_break_spots(values)
      }
    }
    
    syms := get_symmetries()
    sym_str : string
    sym_cstr : cstring
    for s,idx in syms {
      if idx == 0 {
        sym_str = fmt.tprintf("%s", s.str)
      } else {
        sym_str = fmt.tprintf("%s\n%s", sym_str, s.str)
      }
    }
    cstr = strings.clone_to_cstring(sym_str); defer delete(cstr)
    active : i32 = 0
    for s,idx in syms {
      if values.symmetry == s.str {
        active = s.num
        break
      }
    }
    if GuiDropdownBox(Rectangle{f32(w) - 185, 215, 160, 20}, cstr, &active, dropdown_toggle) {
      dropdown_toggle = !dropdown_toggle
      for s,idx in syms {
        if active == s.num {
          values.symmetry = s.str
        }
      }
      clean_breaks(values)
      alloc_breaks(values)
      random_break_spots(values)
    }
    
  }
}

@test
test_knots :: proc(t: ^testing.T) {
  using raylib
  using knots
  
  ta := mem.Tracking_Allocator{};
  mem.tracking_allocator_init(&ta, context.allocator);
  context.allocator = mem.tracking_allocator(&ta);

  w : i32
  h : i32
  WIDTH  :: 500
  HEIGHT :: 500

  SetConfigFlags(ConfigFlags{ConfigFlag.WINDOW_RESIZABLE})
  InitWindow(WIDTH, HEIGHT, "Knot Generator")
  SetTargetFPS(60)

  values : Values
  values.show_menu = false
  values.grid = [?]i32{2,3}
  values.grid_spacing = 80
  values.margin = [?]i32{10,10}
  values.rounding = 0.80  // unused
  values.thickness = 0.50
  values.gap = .07
  values.symmetry = ""
  values.elbow_segments = 4
  values.show_breaks = false
  values.breaks_percent = 0.5
  alloc_breaks(&values)
  random_break_spots(&values)

  for !WindowShouldClose() {
    // Update ------------------------------
    w = GetScreenWidth()
    h = GetScreenHeight()
    
    // Draw   ------------------------------
    BeginDrawing()
    ClearBackground(WHITE)
    
    if values.show_breaks {
      draw_grid(w, h, &values)
      draw_bounds(w, h, &values)
    }
    draw_knot(&values)
    draw_menu(w, h, &values)
    
    EndDrawing()
  }
  CloseWindow()

  clean_breaks(&values)
  delete(values.break_spots)
  delete(values.cells)
  
  if len(ta.allocation_map) > 0 {
    for _, v in ta.allocation_map {
      fmt.printf("Leaked %v bytes @ %v\n", v.size, v.location);
    }
  }
  if len(ta.bad_free_array) > 0 {
    fmt.println("Bad frees:");
    for v in ta.bad_free_array {
      fmt.println(v);
    }
  }
}
