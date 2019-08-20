# @summary End-to-end test for CMDB Instance retrieve / update.
#
# You'll need to provide a `sys_id` of an Application in your CMDB and a
# `target_value` different from its current value.
plan servicenow::test_cmdbi_ru (
  TargetSpec $nodes,
  String[1] $class = 'cmdb_ci_appl',
  Servicenow::Sys_id $sys_id = '6ed461b5dbaf13c4a38b9637db961996',
  String[1] $attribute = 'version',
  String[1] $target_value = '1.2.3',
) {
  $get_args = {
    'class'     => $class,
    'sys_id'    => $sys_id,
    'attribute' => $attribute,
  }

  $set_args = {
    'class'     => $class,
    'sys_id'    => $sys_id,
  }

  $current_value_rs = run_task('servicenow::get_cmdbi_attribute', $nodes, 'Getting current CI attribute value', $get_args)
  $current_value = $current_value_rs.first().value()['value']
  if $current_value == $target_value {
    fail_plan("The CMDB is already set to the target value ${target_value}, cannot run the test")
  }

  run_task('servicenow::update_cmdbi_record', $nodes, 'Setting new CI attribute value',
    $set_args + { 'attributes' => { $attribute => $target_value } })

  $new_value_rs = run_task('servicenow::get_cmdbi_attribute', $nodes, 'Getting new CI attribute value', $get_args)
  $new_value = $new_value_rs.first().value()['value']
  if $new_value != $target_value {
    fail_plan("We updated the CMDB with ${attribute}=${target_value} but it is actually set to ${new_value}")
  }

  run_task('servicenow::update_cmdbi_record', $nodes, 'Rolling back CI attribute value',
    $set_args + { 'attributes' => { $attribute => $current_value } })
}
