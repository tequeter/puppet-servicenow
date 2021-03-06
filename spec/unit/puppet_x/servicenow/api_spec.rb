require 'spec_helper'
require 'puppet_x/servicenow/api'

PXSNA = PuppetX::Servicenow::API

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

  describe '#execute_request' do
    let(:api) { described_class.new(config: api_config) }

    it 'does not retry client errors' do
      expect(api).to receive(:create_request).and_raise(RestClient::RequestFailed.new(nil, 404))
      expect(api).not_to receive(:sleep)
      expect { api.execute_request(:method, 'path', 'payload') }.to raise_error(RestClient::RequestFailed)
    end

    it 'retries network errors' do
      expect(api).to receive(:create_request).and_raise(RestClient::RequestTimeout)
      expect(api).to receive(:sleep).with(1)
      expect(api).to receive(:create_request).and_raise(RestClient::RequestTimeout)
      expect(api).to receive(:sleep).with(2)
      expect(api).to receive(:create_request).and_raise(RestClient::RequestTimeout)
      expect(api).to receive(:sleep).with(4)
      expect(api).to receive(:create_request).and_raise(RestClient::RequestTimeout)

      expect { api.execute_request(:method, 'path', 'payload') }.to raise_error(RestClient::RequestTimeout)
    end
  end

  describe '#call_snow' do
    let(:api) { described_class.new(config: api_config) }
    let(:response) { instance_double('RestClient::Response') }

    it 'assembles the URL' do
      expect(api).to receive(:execute_request).with(:method, 'https://example.com/path', 'payload').and_return(response)
      expect(response).to receive(:body).and_return('{}')

      api.call_snow(:method, 'path', 'payload', PXSNA::STRING_HASH_SCHEMA)
    end

    it 'fails on invalid JSON result' do
      expect(api).to receive(:execute_request).and_return(response)
      expect(response).to receive(:body).and_return('foo')

      expect { api.call_snow(:foo, 'foo', 'foo', PXSNA::STRING_HASH_SCHEMA) }.to raise_error(JSON::ParserError)
    end

    it 'fails on invalid result schema' do
      expect(api).to receive(:execute_request).and_return(response)
      expect(response).to receive(:body).and_return('{}')

      schema = PXSNA::TABLE_RECORD_RESULT_SCHEMA

      expect { api.call_snow(:foo, 'foo', 'foo', schema) }.to raise_error(%r{Invalid result})
    end

    it 'succeeds on valid result schema' do
      expect(api).to receive(:execute_request).and_return(response)
      expect(response).to receive(:body).and_return(%({"result": {"sys_id": "#{sample_sys_id}"}}))

      schema = PXSNA::TABLE_RECORD_RESULT_SCHEMA

      expect(api.call_snow(:foo, 'foo', 'foo', schema)).to eql('result' => { 'sys_id' => sample_sys_id })
    end
  end

  describe '#get_cmdbi_record' do
    url = "api/now/v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

    it 'defers to call_snow()' do
      sample_hash = { 'attributes' => { 'key' => 'value' }, 'outbound_relations' => [], 'inbound_relations' => [] }
      schema = PuppetX::Servicenow::API::CMDBI_RECORD_RESULT_SCHEMA
      api = described_class.new(config: api_config)

      expect(api).to receive(:call_snow).with(:get, url, nil, schema).and_return('result' => sample_hash)
      expect(api.get_cmdbi_record('cmdb_ci_appl', sample_sys_id)).to eql(sample_hash)
    end
  end

  describe '#patch_cmdbi_record' do
    it 'defers to call_snow()' do
      payload_in    = { 'attributes' => { 'key' => 'value' } }
      payload_fixed = { 'attributes' => { 'key' => 'value' }, 'source' => 'ServiceNow' }

      api = described_class.new(config: api_config)
      url = "api/now/v1/cmdb/instance/cmdb_ci_appl/#{sample_sys_id}"

      expect(api).to receive(:call_snow).with(:patch, url, payload_fixed, PXSNA::STRING_HASH_SCHEMA)
      api.patch_cmdbi_record('cmdb_ci_appl', sample_sys_id, payload_in)
    end
  end

  describe '#get_table_record' do
    url = "api/now/v2/table/change_request/#{sample_sys_id}"

    it 'defers to call_snow()' do
      sample_hash = { 'description' => 'foo' }
      schema = PuppetX::Servicenow::API::TABLE_RECORD_RESULT_SCHEMA
      api = described_class.new(config: api_config)

      expect(api).to receive(:call_snow).with(:get, url, nil, schema).and_return('result' => sample_hash)
      expect(api.get_table_record('change_request', sample_sys_id)).to eql(sample_hash)
    end
  end
end
