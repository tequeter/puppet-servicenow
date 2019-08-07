require 'json'
require 'base64'
require 'rest-client'
require 'yaml'
require 'rschema'

# rubocop:disable Style/Documentation
module PuppetX; end
module PuppetX::Servicenow; end
# rubocop:enable Style/Documentation

# Thin wrapper around ServiceNow's REST API.
class PuppetX::Servicenow::API
  CONFIG_SCHEMA = RSchema.define_hash do
    {
      'uri'      => pipeline(_String, predicate('http(s) uri') { |x| x.start_with?(%r{https?://}) }),
      'user'     => _String,
      'password' => _String,
    }
  end

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
  # - config_path: where to find a YAML file with keys uri, user, and password.
  # - config: the same content as a hash. Either one of config and config_path
  #   is required.
  # - rest_client: for unit testing, use a different REST lib than RestClient.
  def initialize(**args)
    @rest = args[:rest_client] || RestClient

    @config = self.class.get_initialize_config(args)
    config_check = CONFIG_SCHEMA.validate(@config)
    raise "Error in provided configuration: #{config_check.error}" unless config_check.valid?

    @uri = @config['uri']

    userpass = "#{@config['user']}:#{@config['password']}"
    @authorization = "Basic #{Base64.strict_encode64(userpass)}"
  end

  def get(path)
    response = @rest.get(
      "#{@uri}/#{path}",
      authorization: @authorization,
      accept: :json,
    )

    JSON.parse(response)
  end

  def get_cmdbi_record(clazz, sys_id)
    json = get("cmdb/instance/#{clazz}/#{sys_id}")
    result = json['result']
    unless result && result['attributes'] && result['outbound_relations'] && result['inbound_relations']
      Puppet.debug(result)
      raise 'The ServiceNow API was successful, but did not contain a complete result. See the --debug log.'
    end

    result
  end
end
