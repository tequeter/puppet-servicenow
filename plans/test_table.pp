# @summary End-to-end test for Table Record tasks.
#
# This test:
#
# 1. Creates a new incident.
# 2. Updates its short description.
# 3. Verifies it is set as expected.
#
# The incident is not deleted afterwards because the user running the test may
# not have the right to do so. The test is not expected to be run on a
# production ServiceNow instance.
#
# @param nodes
#   Must match the ServiceNow entry in your inventory. Multiple nodes are not
#   supported.
# @param table
#   Internal ServiceNow table name.
# @param attribute
#   Table attribute (field) we'll test updating.
# @param target_value1
#   The value we'll set the attribute to at first.
# @param target_value2
#   The value we'll set the attribute to when updating the record.
plan servicenow::test_table (
  TargetSpec $nodes,
  String[1] $table = 'incident',
  String[1] $attribute = 'short_description',
  String[1] $target_value1 = 'Test from Bolt - init',
  String[1] $target_value2 = 'Test from Bolt - updated',
) {
  # 1. Creates a new incident.
  $record_attrs_rs = run_task('servicenow::create_table_record', $nodes, 'Creating the new record', {
    table      => $table,
    attributes => { $attribute => $target_value1 },
  })
  [ $sys_id, $number ] = $record_attrs_rs.first().value()['sys_id', 'number']

  # 2. Updates its description.
  run_task('servicenow::update_table_record', $nodes, 'Setting new Table record attribute value', {
    table      => $table,
    sys_id     => $sys_id,
    attributes => { $attribute => $target_value2 }})

  # 3. Verifies it is set as expected.
  $new_value_rs = run_task('servicenow::get_table_attribute', $nodes, 'Getting new attribute value', {
    table     => $table,
    sys_id    => $sys_id,
    attribute => $attribute,
  })
  $new_value = $new_value_rs.first().value()['value']
  if $new_value != $target_value2 {
    fail_plan("We updated the Table record with ${attribute}=${target_value2} but it is actually set to ${new_value}")
  }

  return {
    sys_id => $sys_id,
    number => $number,
  }
}
