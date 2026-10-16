# Recreate the Vivado project without generated GT Wizard IP.
# The complete FPGA part is a board-level input and must be supplied by the user.

proc canonical_path_key {path_name} {
  return [string tolower [string map {\\ /} [file normalize $path_name]]]
}

proc path_is_within {root_name path_name} {
  set root_key [canonical_path_key $root_name]
  set path_key [canonical_path_key $path_name]
  return [expr {$path_key eq $root_key ||
                [string first "${root_key}/" $path_key] == 0}]
}

proc collect_hdl_keys {directory_name} {
  set result {}
  foreach entry [glob -nocomplain -directory $directory_name *] {
    if {[file isdirectory $entry]} {
      set result [concat $result [collect_hdl_keys $entry]]
    } elseif {[string tolower [file extension $entry]] in {.v .sv}} {
      lappend result [canonical_path_key $entry]
    }
  }
  return $result
}

proc list_difference {left_list right_list} {
  set right_set [dict create]
  foreach item $right_list {
    dict set right_set $item 1
  }
  set result {}
  foreach item $left_list {
    if {![dict exists $right_set $item]} {
      lappend result $item
    }
  }
  return $result
}

proc require_before {ordered_list provider consumer} {
  set provider_index [lsearch -exact $ordered_list $provider]
  set consumer_index [lsearch -exact $ordered_list $consumer]
  if {$provider_index < 0} {
    error "Compile-order provider is absent from filelist.f: $provider"
  }
  if {$consumer_index < 0} {
    error "Compile-order consumer is absent from filelist.f: $consumer"
  }
  if {$provider_index >= $consumer_index} {
    error "Invalid compile order: $provider must precede $consumer"
  }
}

set script_dir    [file normalize [file dirname [info script]]]
set root_dir      [file normalize [file join $script_dir ..]]
set build_dir     [file normalize [file join $root_dir build vivado]]
set filelist_path [file normalize [file join $script_dir filelist.f]]
set xdc_path      [file normalize [file join $root_dir constr pcie_gen12_phy_x1_rp.xdc]]

if {![file isfile $filelist_path]} {
  error "Missing compile manifest: $filelist_path"
}
if {![file isfile $xdc_path]} {
  error "Missing constraints file: $xdc_path"
}

# Parse filelist.f before changing project state. It is the single source of
# truth for both synthesis and simulation source membership and source order.
set manifest_fh [open $filelist_path r]
set manifest_rel {}
set manifest_keys {}
set rtl_files {}
set tb_files {}
set seen_paths [dict create]
set missing_files {}
set line_number 0
while {[gets $manifest_fh line] >= 0} {
  incr line_number
  regsub {#.*$} $line {} line
  set relative_path [string map {\\ /} [string trim $line]]
  if {$relative_path eq ""} {
    continue
  }
  if {[file pathtype $relative_path] ne "relative"} {
    close $manifest_fh
    error "filelist.f:$line_number must use a project-relative path: $relative_path"
  }

  set absolute_path [file normalize [file join $root_dir {*}[file split $relative_path]]]
  if {![path_is_within $root_dir $absolute_path]} {
    close $manifest_fh
    error "filelist.f:$line_number escapes the project root: $relative_path"
  }
  set path_key [canonical_path_key $absolute_path]
  if {[dict exists $seen_paths $path_key]} {
    set first_line [dict get $seen_paths $path_key]
    close $manifest_fh
    error "Duplicate source in filelist.f at lines $first_line and $line_number: $relative_path"
  }
  dict set seen_paths $path_key $line_number

  if {![file isfile $absolute_path]} {
    lappend missing_files $relative_path
  }
  if {[string match "rtl/*" $relative_path]} {
    if {![string equal -nocase [file extension $relative_path] ".v"]} {
      close $manifest_fh
      error "filelist.f:$line_number RTL must be Verilog (.v): $relative_path"
    }
    lappend rtl_files $absolute_path
  } elseif {[string match "tb/*" $relative_path]} {
    if {[string tolower [file extension $relative_path]] ni {.v .sv}} {
      close $manifest_fh
      error "filelist.f:$line_number is not a Verilog/SystemVerilog source: $relative_path"
    }
    lappend tb_files $absolute_path
  } else {
    close $manifest_fh
    error "filelist.f:$line_number is outside rtl/ and tb/: $relative_path"
  }
  lappend manifest_rel $relative_path
  lappend manifest_keys $path_key
}
close $manifest_fh

if {[llength $missing_files] != 0} {
  error "Sources named by filelist.f do not exist: [join $missing_files {, }]"
}

# Fail closed when a new source is added to rtl/ or tb/ without updating the
# manifest, or when the manifest retains a stale source.
set tree_keys [lsort -unique [concat \
  [collect_hdl_keys [file join $root_dir rtl]] \
  [collect_hdl_keys [file join $root_dir tb]]]]
set manifest_keys [lsort -unique $manifest_keys]
set unlisted_sources [list_difference $tree_keys $manifest_keys]
set stale_sources    [list_difference $manifest_keys $tree_keys]
if {[llength $unlisted_sources] != 0} {
  error "Verilog/SystemVerilog sources missing from filelist.f: [join $unlisted_sources {, }]"
}
if {[llength $stale_sources] != 0} {
  error "Stale Verilog/SystemVerilog paths in filelist.f: [join $stale_sources {, }]"
}

# Explicit dependency assertions make accidental manifest reordering visible.
require_before $manifest_rel tb/tb_common/pcie_gen12_phy_pkg.sv tb/tb_common/pcie_gen12_phy_timing_pkg.sv
require_before $manifest_rel rtl/gt/gty_behavioral_model.v rtl/gt/pcie_gty_adapter_x1.v
require_before $manifest_rel tb/tb_common/pcie_gen12_phy_pkg.sv tb/golden/golden_scrambler.sv
require_before $manifest_rel tb/tb_common/pcie_gen12_phy_pkg.sv tb/golden/golden_ordered_set.sv
require_before $manifest_rel tb/tb_common/pcie_gen12_phy_pkg.sv tb/tb_common/phy_tb_pkg.sv
require_before $manifest_rel tb/tb_common/phy_tb_pkg.sv tb/tb_PHY_V_001/tb_PHY_V_001.sv
require_before $manifest_rel rtl/pcie_gen12_phy_x1_rp.v tb/tb_common/phy_top_harness.sv
foreach dependent_test {009 010 011 012} {
  require_before $manifest_rel \
    tb/tb_PHY_V_008/tb_PHY_V_008.sv \
    tb/tb_PHY_V_${dependent_test}/tb_PHY_V_${dependent_test}.sv
}
for {set test_number 1} {$test_number <= 15} {incr test_number} {
  set test_id [format "%03d" $test_number]
  set test_path "tb/tb_PHY_V_${test_id}/tb_PHY_V_${test_id}.sv"
  if {[lsearch -exact $manifest_rel $test_path] < 0} {
    error "Required testbench source is absent from filelist.f: $test_path"
  }
  require_before $manifest_rel tb/tb_common/pcie_gen12_phy_pkg.sv $test_path
  require_before $manifest_rel tb/tb_common/pcie_gen12_phy_timing_pkg.sv $test_path
}

if {![info exists ::env(PCIE_FPGA_PART)] || $::env(PCIE_FPGA_PART) eq ""} {
  error "Set PCIE_FPGA_PART to the frozen full FPGA part, including package and speed grade."
}
set fpga_part $::env(PCIE_FPGA_PART)

create_project pcie_gen12_phy_x1_rp $build_dir -part $fpga_part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

# sources_1 deliberately has no GT_BEHAV_MODEL define: the adapter therefore
# selects its synthesis-default GTYE4_CHANNEL path.
add_files -norecurse -fileset sources_1 $rtl_files
set_property top pcie_gen12_phy_x1_rp [get_filesets sources_1]
foreach source_path $rtl_files {
  set source_object [get_files -quiet -of_objects [get_filesets sources_1] $source_path]
  if {[llength $source_object] != 1} {
    error "Expected exactly one sources_1 object for $source_path"
  }
  set_property file_type Verilog $source_object
}

set behavioral_model [file normalize [file join $root_dir rtl gt gty_behavioral_model.v]]
set behavioral_object [get_files -quiet -of_objects [get_filesets sources_1] $behavioral_model]
if {[llength $behavioral_object] != 1} {
  error "Expected exactly one gty_behavioral_model.v source object"
}
set_property used_in_synthesis false $behavioral_object
set_property used_in_simulation true $behavioral_object

add_files -norecurse -fileset constrs_1 $xdc_path

# Add verification sources in manifest order; do not use glob ordering here.
add_files -norecurse -fileset sim_1 $tb_files
foreach source_path $tb_files {
  set source_object [get_files -quiet -of_objects [get_filesets sim_1] $source_path]
  if {[llength $source_object] != 1} {
    error "Expected exactly one sim_1 object for $source_path"
  }
  set_property file_type SystemVerilog $source_object
}
set_property verilog_define {GT_BEHAV_MODEL} [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Created [current_project] for $fpga_part in $build_dir"
puts "Manifest audit passed: [llength $rtl_files] RTL and [llength $tb_files] verification sources."
puts "GT Wizard replacement remains a board-integration step; see scripts/gt_wizard_notes.md."
