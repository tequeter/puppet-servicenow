require 'spec_helper'

describe 'ServiceNow::Sys_id' do
  it { is_expected.to allow_value('95980405dbd8af4027effe9b0c9619ec') }
  it { is_expected.not_to allow_value('test', 'CHG00123456') }
end
