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
  # Required entries in the config_path YAML file.
  CONFIG_SCHEMA = RSchema.define_hash do
    {
      'url'      => pipeline(_String, predicate('http(s) url') { |x| x.start_with?(%r{https?://}) }),
      'user'     => _String,
      'password' => _String,
    }
  end

  # Expected entries in a ServiceNow CMDBI GET response.
  CMDBI_RECORD_SCHEMA = RSchema.define_hash do
    {
      'attributes'         => variable_hash(_String => anything),
      'inbound_relations'  => array(anything),
      'outbound_relations' => array(anything),
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

  # Construct the final ServiceNow URL, call the API, and parse the JSON result.
  # @api private
  def call_snow(method, path, payload)
    url = "#{@url}/#{path}"
    response = create_request(method, url, payload).execute

    Puppet.debug("#{method} to #{url} with payload\n#{payload}\nresults in\n#{response}")

    JSON.parse(response)
  end

  # Fetch a CI by its unique sys_id.
  #
  # The class (clazz) determines the returned attributes, so it must be as
  # exact as possible.
  #
  # Return a hash with attributes, inbound_relations, and outbound_relations
  # string keys.
  def get_cmdbi_record(clazz, sys_id)
    json = call_snow(:get, "api/now/v1/cmdb/instance/#{clazz}/#{sys_id}", nil)
    result = json['result']

    result_check = CMDBI_RECORD_SCHEMA.validate(result)
    raise "Invalid result from successful ServiceNow API call: #{result_check.error}" unless result_check.valid?

    result
  end

  # Update some fields in an existing CI.
  #
  # "payload" typically includes an "attributes" key, a hash with attributes to
  # update.
  def patch_cmdbi_record(clazz, sys_id, payload)
    payload['source'] ||= 'ServiceNow'
    call_snow(:patch, "api/now/v1/cmdb/instance/#{clazz}/#{sys_id}", payload)
  end
end
