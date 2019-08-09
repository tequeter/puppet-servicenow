require 'spec_helper'
require 'bolt_spec/run'
require 'puppet_x/servicenow/api'

sample_snow_instance = 'my.service-now.com'
sample_class = 'cmdb_ci_appl'
sample_sys_id = '00000000000000000000000000000000'
sample_attrs = { 'version' => '1.2.3' }
sample_conf_path = '/etc/my.service-now.com.yaml'

describe 'run_task' do
  include BoltSpec::Run

  it 'should attempt to call the ServiceNow API' do
    # Attempt to intercept API calls made by the task implementation. However,
    # this does not work because the "in-process" run_task() actually runs the
    # task in a separate Ruby interpreter, which thus ignores our mock version.
    api = instance_double('PuppetX::Servicenow::API')
    expect(PuppetX::Servicenow::API).to receive(:new).with(config_path: sample_conf_path).and_return(api)
    expect(api).to receive(:patch_cmdbi_record).with(sample_class, sample_sys_id, sample_attrs)

    inventory = {
      'nodes' => [
        {
          'name' => sample_snow_instance,
          'config' => {
            'transport' => 'remote',
            'remote'    => {
              'servicenow_config_path' => sample_conf_path,
            },
          },
        },
      ],
    }

    params = {
      'class'      => sample_class,
      'sys_id'     => sample_sys_id,
      'attributes' => sample_attrs,
    }

    bolt_config = {
      'modulepath' => File.join(RSPEC_ROOT, 'fixtures', 'modules'),
    }

    result = run_task('servicenow::update_cmdbi_record', sample_snow_instance, params, inventory: inventory, config: bolt_config)

    expect(result[0]['status']).to eq('success'), "expected success, got: #{result.inspect}"
  end
end
