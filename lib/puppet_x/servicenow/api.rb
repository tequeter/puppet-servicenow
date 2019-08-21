require 'puppet'
require 'json'
require 'base64'
require 'rest-client'
require 'yaml'
require 'rschema'

# 3rd party Puppet Ruby Extensions
module PuppetX; end
# Ruby helpers for the ServiceNow module
module PuppetX::Servicenow; end

# Thin wrapper around ServiceNow's REST API.
class PuppetX::Servicenow::API
  # Hash with string keys
  STRING_HASH_SCHEMA = RSchema.define { variable_hash(_String => anything) }

  # An HTTP(S) URL
  HTTP_S_URL_SCHEMA = RSchema.define { predicate('http(s) url') { |x| x.start_with?(%r{https?://}) } }

  # Required entries in the config_path YAML file.
  CONFIG_SCHEMA = RSchema.define_hash do
    {
      'url'      => pipeline(_String, HTTP_S_URL_SCHEMA),
      'user'     => _String,
      'password' => _String,
    }
  end

  # Expected entries in a ServiceNow CMDBI GET response.
  CMDBI_RECORD_RESULT_SCHEMA = RSchema.define_hash do
    {
      'result' => fixed_hash(
        'attributes'         => STRING_HASH_SCHEMA,
        'inbound_relations'  => array(anything),
        'outbound_relations' => array(anything),
      ),
    }
  end

  # Expected entries in a ServiceNow Table response.
  TABLE_RECORD_RESULT_SCHEMA = RSchema.define_hash do
    {
      'result' => pipeline(
        STRING_HASH_SCHEMA,
        predicate('has sys_id attribute') { |x| x.key?('sys_id') },
      ),
    }
  end

  # Abstract loading the configuration.
  # @api private
  def self.get_initialize_config(args)
    if args[:config]
      args[:config]
    elsif args[:config_path]
      YAML.load_file(args[:config_path])
    else
      raise ArgumentError, 'No config* argument specified'
    end
  end

  # Named arguments:
  # - config_path: where to find a YAML file with keys url, user, and password.
  # - config: the same content as a hash. Either one of config and config_path
  #   is required.
  def initialize(**args)
    @config = self.class.get_initialize_config(args)
    config_check = CONFIG_SCHEMA.validate(@config)
    raise "Error in provided configuration: #{config_check.error}" unless config_check.valid?

    @url = @config['url']

    userpass = "#{@config['user']}:#{@config['password']}"
    @authorization = "Basic #{Base64.strict_encode64(userpass)}"
  end

  # Create a RestClient::Request with the proper arguments.
  # @api private
  def create_request(method, url, payload)
    payload = payload.to_json if payload.respond_to?(:each)
    RestClient::Request.new(
      method: method,
      url: url,
      payload: payload,
      headers: {
        authorization: @authorization,
        accept: :json,
        content_type: :json,
      },
    )
  end

  # Wrapper around create_request() for easier unit testing
  # @api private
  def execute_request(*args)
    create_request(*args).execute
  end

  # Raise an exception if payload doesn't match schema.
  # @api private
  def validate_response_payload(payload, schema)
    check = schema.validate(payload)
    raise "Invalid result from successful ServiceNow API call: #{check.error.inspect}" unless check.valid?
  end

  # Construct the final ServiceNow URL, call the API, parse, and validate the JSON result.
  # @api private
  def call_snow(method, path, payload, schema)
    url = "#{@url}/#{path}"

    response = execute_request(method, url, payload)
    Puppet.debug("#{method} to #{url} with payload\n#{payload}\nresults in\n#{response}")

    response_payload = JSON.parse(response.body)
    validate_response_payload(response_payload, schema)

    response_payload
  end

  # Retrieve a CI by its unique sys_id.
  #
  # The class (clazz) determines the returned attributes, so it must be as
  # exact as possible.
  #
  # Return a hash with attributes, inbound_relations, and outbound_relations
  # string keys.
  def get_cmdbi_record(clazz, sys_id)
    call_snow(:get, "api/now/v1/cmdb/instance/#{clazz}/#{sys_id}", nil, CMDBI_RECORD_RESULT_SCHEMA)['result']
  end

  # Update some fields in an existing CI.
  #
  # "payload" typically includes an "attributes" key, a hash with attributes to
  # update.
  def patch_cmdbi_record(clazz, sys_id, payload)
    payload['source'] ||= 'ServiceNow'
    call_snow(:patch, "api/now/v1/cmdb/instance/#{clazz}/#{sys_id}", payload, STRING_HASH_SCHEMA)
    nil
  end

  # Retrieve a Table record (most ServiceNow objects) by its unique sys_id.
  #
  # Return a hash of the attributes of the record.
  def get_table_record(table, sys_id)
    call_snow(:get, "api/now/v2/table/#{table}/#{sys_id}", nil, TABLE_RECORD_RESULT_SCHEMA)['result']
  end

  # Update some fields in an existing table record.
  #
  # @example
  #   api.patch_table_record('change_request', 'deadbeefwhatever', {'work_notes' => 'I did stuff'})
  def patch_table_record(table, sys_id, payload)
    call_snow(:patch, "api/now/v2/table/#{table}/#{sys_id}", payload, STRING_HASH_SCHEMA)
    nil
  end

  # Create a new Table record
  #
  # Return a hash with the attributes of the new record.
  def post_table_record(table, payload)
    call_snow(:post, "api/now/v2/table/#{table}", payload, TABLE_RECORD_RESULT_SCHEMA)['result']
  end
end
