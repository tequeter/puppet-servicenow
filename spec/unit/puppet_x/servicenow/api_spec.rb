require 'spec_helper'
require 'puppet_x/servicenow/api'

api_config = {
  'uri'      => 'https://example.com/api/now',
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

    it 'extracts uri and credentials from :config' do
      api = described_class.new(config: api_config)
      expect(api.instance_variable_get(:@uri)).to eq('https://example.com/api/now')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end

    it 'validates the uri' do
      bad_config = api_config.merge('uri' => 'htp://example.com')
      expect { described_class.new(config: bad_config) }.to raise_error(%r{\AError in provided config})
    end

    it 'extracts uri and credentials from :config_path' do
      api = described_class.new(config_path: File.join(RSPEC_ROOT, 'fixtures', 'files', 'example.com.yaml'))
      expect(api.instance_variable_get(:@uri)).to eq('https://example.com/api/now')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end
  end

  describe '#get' do
    headers = { authorization: authorization_header, accept: :json }

    it 'calls the ServiceNow API' do
      expect(RestClient).to receive(:get).with('https://example.com/api/now/foo', headers).and_return('{"key": "value"}')
      api = described_class.new(config: api_config, rest_client: RestClient)
      expect(api.get('foo')).to eq('key' => 'value')
    end

    # RestClient raises on errors, no point test that here

    it 'fails on invalid JSON result' do
      expect(RestClient).to receive(:get).and_return('foo')
      api = described_class.new(config: api_config, rest_client: RestClient)
      expect { api.get('foo') }.to raise_error(JSON::ParserError)
    end
  end

  describe '#get_cmdbi_record' do
    it 'defers to get()' do
      sample_hash = { 'attributes' => { 'key' => 'value' }, 'outbound_relations' => {}, 'inbound_relations' => {} }
      api = described_class.new(config: api_config)

      expect(api).to receive(:get).with("cmdb/instance/cmdb_ci_appl/#{sample_sys_id}").and_return('result' => sample_hash)
      expect(api.get_cmdbi_record('cmdb_ci_appl', sample_sys_id)).to eq(sample_hash)
    end

    it 'checks the result structure' do
      api = described_class.new(config: api_config)

      expect(api).to receive(:get).with("cmdb/instance/cmdb_ci_appl/#{sample_sys_id}").and_return('result' => {})
      expect { api.get_cmdbi_record('cmdb_ci_appl', sample_sys_id) }.to raise_error(%r{complete result})
    end
  end
end
