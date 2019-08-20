# @summary End-to-end test for Table retrieve / update.
#
# This test updates the attribute of an existing record to a new value, ensures
# it is as expected, and rolls back the change.
#
# You'll need to provide an existing `sys_id` in that `table` of your
# ServiceNow instance, and a `target_value` different from its current value.
#
# @param nodes
#   Must match the ServiceNow entry in your inventory. Multiple nodes are not
#   supported.
# @param table
#   Internal ServiceNow table name.
# @param sys_id
#   Internal ServiceNow identifier for an existing record.
# @param attribute
#   Table attribute (field) we'll test updating.
# @param target_value
#   The value we'll set the attribute to.
plan servicenow::test_table_ru (
  TargetSpec $nodes,
  String[1] $table = 'change_request',
  Servicenow::Sys_id $sys_id = '95980405dbd8af4027effe9b0c9619ec',
  String[1] $attribute = 'short_description',
  String[1] $target_value = 'Puppet end-to-end testing',
) {
  $get_args = {
    'table'     => $table,
    'sys_id'    => $sys_id,
    'attribute' => $attribute,
  }

  $set_args = {
    'table'     => $table,
    'sys_id'    => $sys_id,
  }

  $current_value_rs = run_task('servicenow::get_table_attribute', $nodes, 'Getting current attribute value', $get_args)
  $current_value = $current_value_rs.first().value()['value']
  if $current_value == $target_value {
    fail_plan("The Table record field is already set to the target value ${target_value}, cannot run the test")
  }

  run_task('servicenow::update_table_record', $nodes, 'Setting new Table record attribute value',
    $set_args + { attributes => { $attribute => $target_value }})

  $new_value_rs = run_task('servicenow::get_table_attribute', $nodes, 'Getting new attribute value', $get_args)
  $new_value = $new_value_rs.first().value()['value']
  if $new_value != $target_value {
    fail_plan("We updated the Table record with ${attribute}=${target_value} but it is actually set to ${new_value}")
  }

  run_task('servicenow::update_table_record', $nodes, 'Rolling back attribute value',
    $set_args + { attributes => { $attribute => $current_value }})
}
