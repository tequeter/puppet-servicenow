#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper'
require_relative '../lib/puppet_x/servicenow/api'

class SnowTask < TaskHelper
  def task(**kwargs)
    clazz, sys_id = kwargs.values_at(:class, :sys_id)
    config_path = kwargs[:_target][:servicenow_config_path]

    api = PuppetX::Servicenow::API.new(config_path: config_path)
    api.get_cmdbi_record(clazz, sys_id)
  end
end

if $PROGRAM_NAME == __FILE__
  SnowTask.run
end
