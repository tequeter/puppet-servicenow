#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper'
require_relative '../lib/puppet_x/servicenow/api'

class SnowTask < TaskHelper
  def task(table: nil, sys_id: nil, attributes: nil, **kwargs)
    config_path = kwargs[:_target][:servicenow_config_path]

    api = PuppetX::Servicenow::API.new(config_path: config_path)
    api.patch_table_record(table, sys_id, attributes)

    nil
  end
end

if $PROGRAM_NAME == __FILE__
  SnowTask.run
end
