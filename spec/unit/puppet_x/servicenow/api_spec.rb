require 'spec_helper'
require 'puppet_x/servicenow/api'

api_config = {
  'url'      => 'https://example.com',
  'user'     => 'user',
  'password' => 'password',
}

# Plain text: "user:password"
authorization_header = 'Basic dXNlcjpwYXNzd29yZA=='

sample_sys_id = '00000000000000000000000000000000'

sample_payload_hash = { 'pay' => 'load' }
sample_payload_stringified = '{"pay":"load"}'

describe PuppetX::Servicenow::API do
  describe '#initialize' do
    it 'fails without a config* argument' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'extracts url and credentials from :config' do
      api = described_class.new(config: api_config)
      expect(api.instance_variable_get(:@url)).to eq('https://example.com')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end

    it 'validates the url' do
      bad_config = api_config.merge('url' => 'htp://example.com')
      expect { described_class.new(config: bad_config) }.to raise_error(%r{\AError in provided config})
    end

    it 'extracts url and credentials from :config_path' do
      api = described_class.new(config_path: File.join(RSPEC_ROOT, 'fixtures', 'files', 'example.com.yaml'))
      expect(api.instance_variable_get(:@url)).to eq('https://example.com')
      expect(api.instance_variable_get(:@authorization)).to eq(authorization_header)
    end
  end

  describe '#create_request' do
    api = described_class.new(config: api_config)
    request = api.create_request(:patch, 'https://example.com/path1', sample_payload_hash)

    it 'sets the method' do
      expect(request.method).to eq('patch')
    end

    it 'sets the URL' do
      expect(request.url).to eq('https://example.com/path1')
    end

    it 'sets the headers correctly' do
      expect(request.processed_headers).to include(
        'Accept'        => 'application/json',
        'Content-Type'  => 'application/json',
        'Authorization' => authorization_header,
      )
    end

    it 'stringifies the payload' do
      expect(request.payload.to_s).to eq(sample_payload_stringified)
    end
  end

  describe '#call_snow' do
    let(:api) { described_class.new(config: api_config) }
    let(:request) { instance_double('RestClient::Request') }

    it 'assembles the URL' do
      expect(api).to receive(:create_request).with(:method, 'https://example.com/path', 'payload').and_return(request)
      expect(request).to receive(:execute).and_return('{}')

      api.call_snow(:method, 'path', 'payload')
    end

    it 'fails on invalid JSON result' do
      expect(api).to receive(:create_request).and_return(request)
      expect(request).to receive(:execute).and_return('foo')

      expect { api.call_snow(:foo, 'foo', 'foo') }.to raise_error(JSON::ParserError)
    end
  end

  describe '#get_cmdbi_record' do
    url = "api/now/v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

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
      url = "api/now/v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

      expect(api).to receive(:call_snow).with(:patch, url, payload_fixed)
      api.patch_cmdbi_record('cmdb_ci_appl', sample_sys_id, payload_in)
    end
  end
end
