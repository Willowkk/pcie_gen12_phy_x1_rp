# Usage after scripts/create_project.tcl has created the project:
#   vivado -mode batch -source scripts/run_sim.tcl -tclargs PHY_V_004
#   vivado -mode batch -source scripts/run_sim.tcl -tclargs all
# Multiple IDs are accepted. With no IDs or with the single ID "all",
# PHY_V_001 through PHY_V_015 run in separate behavioral elaborations.

proc canonical_path_key {path_name} {
  return [string tolower [string map {\\ /} [file normalize $path_name]]]
}

proc require_project_file_once {fileset_object source_path} {
  set matches [get_files -quiet -of_objects $fileset_object $source_path]
  if {[llength $matches] != 1} {
    error "Expected exactly one project source object for $source_path; found [llength $matches]"
  }
}

proc require_sim_compile_order {provider_path consumer_path} {
  set provider_key [canonical_path_key $provider_path]
  set consumer_key [canonical_path_key $consumer_path]
  set provider_index -1
  set consumer_index -1
  set index 0
  foreach source_object [get_files -quiet -compile_order sources -used_in simulation] {
    set source_name [get_property NAME $source_object]
    if {$source_name ne ""} {
      set source_key [canonical_path_key $source_name]
      if {$source_key eq $provider_key} {
        set provider_index $index
      }
      if {$source_key eq $consumer_key} {
        set consumer_index $index
      }
    }
    incr index
  }
  if {$provider_index < 0 || $consumer_index < 0} {
    error "Simulation compile order omits provider or consumer: $provider_path -> $consumer_path"
  }
  if {$provider_index >= $consumer_index} {
    error "Simulation compile order is invalid: $provider_path must precede $consumer_path"
  }
}

set script_dir  [file normalize [file dirname [info script]]]
set root_dir    [file normalize [file join $script_dir ..]]
set project_xpr [file normalize \
  [file join $root_dir build vivado pcie_gen12_phy_x1_rp.xpr]]

set open_projects [get_projects -quiet]
if {[llength $open_projects] == 0} {
  if {![file isfile $project_xpr]} {
    error "Project is not open and does not exist at $project_xpr; run scripts/create_project.tcl first."
  }
  open_project $project_xpr
  set open_projects [get_projects -quiet]
}
if {[llength $open_projects] != 1} {
  error "Open exactly one project before run_sim.tcl."
}
set source_filesets [get_filesets -quiet sources_1]
set sim_filesets    [get_filesets -quiet sim_1]
if {[llength $source_filesets] != 1 || [llength $sim_filesets] != 1} {
  error "The open project must contain exactly one sources_1 and one sim_1 fileset."
}
set source_fileset [lindex $source_filesets 0]
set sim_fileset    [lindex $sim_filesets 0]

set all_tests {}
for {set test_number 1} {$test_number <= 15} {incr test_number} {
  lappend all_tests [format "PHY_V_%03d" $test_number]
}

if {[llength $argv] == 0 ||
    ([llength $argv] == 1 && [string equal -nocase [lindex $argv 0] "all"])} {
  set tests $all_tests
} else {
  set tests {}
  foreach requested_test $argv {
    set requested_test [string toupper $requested_test]
    if {[lsearch -exact $all_tests $requested_test] < 0} {
      error "Unknown test '$requested_test'; expected PHY_V_001..PHY_V_015."
    }
    if {[lsearch -exact $tests $requested_test] >= 0} {
      error "Duplicate requested test: $requested_test"
    }
    lappend tests $requested_test
  }
}

# The synthesis fileset must retain the adapter's default GTYE4 path.
foreach synthesis_define [get_property verilog_define $source_fileset] {
  if {$synthesis_define eq "GT_BEHAV_MODEL" ||
      [string match "GT_BEHAV_MODEL=*" $synthesis_define]} {
    error "GT_BEHAV_MODEL must not be defined on sources_1."
  }
}

# Preserve unrelated simulation defines while normalizing the behavioral-model
# selector to one exact GT_BEHAV_MODEL entry.
set sim_defines {}
foreach simulation_define [get_property verilog_define $sim_fileset] {
  if {$simulation_define ne "GT_BEHAV_MODEL" &&
      ![string match "GT_BEHAV_MODEL=*" $simulation_define]} {
    lappend sim_defines $simulation_define
  }
}
lappend sim_defines GT_BEHAV_MODEL
set_property verilog_define $sim_defines $sim_fileset

set fixture_path [file normalize \
  [file join $root_dir tb tb_PHY_V_008 tb_PHY_V_008.sv]]
require_project_file_once $sim_fileset $fixture_path

# Check all 15 tops up front, before any simulator process is launched.
foreach test_id $all_tests {
  set test_path [file normalize [file join $root_dir tb tb_${test_id} tb_${test_id}.sv]]
  require_project_file_once $sim_fileset $test_path
}

foreach test_id $tests {
  set top_name "tb_${test_id}"
  set test_path [file normalize [file join $root_dir tb $top_name ${top_name}.sv]]
  puts "=== Elaborating $top_name ==="
  set_property top $top_name $sim_fileset
  update_compile_order -fileset sim_1

  # PHY-V-009..012 instantiate the fixture declared by PHY-V-008.
  if {[lsearch -exact {PHY_V_009 PHY_V_010 PHY_V_011 PHY_V_012} $test_id] >= 0} {
    require_sim_compile_order $fixture_path $test_path
  }

  launch_simulation -simset sim_1 -mode behavioral
  run all
  close_sim -force
}
puts "Requested XSim invocations completed; use each TB_RESULT line as the pass/fail authority."
