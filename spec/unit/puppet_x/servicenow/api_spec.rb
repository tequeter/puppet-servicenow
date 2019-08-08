require 'spec_helper'
require 'puppet_x/servicenow/api'

api_config = {
  'url'      => 'https://example.com/api/now',
  'user'     => 'user',
  'password' => 'password',
}

# Plain text: "user:password"
authorization_header = 'Basic dXNlcjpwYXNzd29yZA=='

sample_sys_id = '00000000000000000000000000000000'

describe PuppetX::Servicenow::API do
  describe '#initialize' do
    it 'fails without a config* argument' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'extracts url and credentials from :config' do
      api = described_class.new(config: api_config)
      expect(api.instance_variable_get(:@url)).to eq('https://example.com/api/now')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end

    it 'validates the url' do
      bad_config = api_config.merge('url' => 'htp://example.com')
      expect { described_class.new(config: bad_config) }.to raise_error(%r{\AError in provided config})
    end

    it 'extracts url and credentials from :config_path' do
      api = described_class.new(config_path: File.join(RSPEC_ROOT, 'fixtures', 'files', 'example.com.yaml'))
      expect(api.instance_variable_get(:@url)).to eq('https://example.com/api/now')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end
  end

  describe '#call_snow' do
    payload = '{"pay": "load"}'
    args = {
      method: :sew,
      url: 'https://example.com/api/now/foo',
      authorization: authorization_header,
      payload: payload,
      accept: :json,
      content_type: :json,
    }

    it 'calls the ServiceNow API' do
      expect(RestClient::Request).to receive(:execute).with(args).and_return('{"key": "value"}')
      api = described_class.new(config: api_config)
      expect(api.call_snow(:sew, 'foo', payload)).to eq('key' => 'value')
    end

    # RestClient raises on errors, no point testing that here

    it 'fails on invalid JSON result' do
      expect(RestClient::Request).to receive(:execute).and_return('foo')
      api = described_class.new(config: api_config)
      expect { api.call_snow(:sew, 'foo', payload) }.to raise_error(JSON::ParserError)
    end
  end

  describe '#get_cmdbi_record' do
    url = "v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

    it 'defers to call_snow()' do
      sample_hash = { 'attributes' => { 'key' => 'value' }, 'outbound_relations' => {}, 'inbound_relations' => {} }
      api = described_class.new(config: api_config)

      expect(api).to receive(:call_snow).with(:get, url, nil).and_return('result' => sample_hash)
      expect(api.get_cmdbi_record('cmdb_ci_appl', sample_sys_id)).to eq(sample_hash)
    end

    it 'checks the result structure' do
      api = described_class.new(config: api_config)

      expect(api).to receive(:call_snow).with(:get, url, nil).and_return('result' => {})
      expect { api.get_cmdbi_record('cmdb_ci_appl', sample_sys_id) }.to raise_error(%r{complete result})
    end
  end

  describe '#patch_cmdbi_record' do
    it 'defers to call_snow()' do
      payload_in    = { 'attributes' => { 'key' => 'value' } }
      payload_fixed = { 'attributes' => { 'key' => 'value' }, 'source' => 'ServiceNow' }

      api = described_class.new(config: api_config)
      url = "v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

      expect(api).to receive(:call_snow).with(:patch, url, payload_fixed)
      api.patch_cmdbi_record('cmdb_ci_appl', sample_sys_id, payload_in)
    end
  end
end
