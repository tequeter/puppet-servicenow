require 'json'
require 'base64'
require 'rest-client'

# rubocop:disable Style/Documentation
module PuppetX; end
module PuppetX::Servicenow; end
# rubocop:enable Style/Documentation

class PuppetX::Servicenow::API
  def self.uri_regexp_string()
    '\A(https?://)([^:]+):([^@]+)@(.*)\Z'
  end

  def initialize(**args)
    @rest = args[:rest_client] || RestClient

    lookup_options = args[:lookup_options]

    @uri = lookup_options['uri']

    all_creds = lookup_options['servicenow_credentials']
    my_creds_fpath = all_creds[@uri]
    my_creds_file = File.new(my_creds_fpath)
    my_creds = my_creds_file.readline.chomp
    raise "Expected a single line user:pass in #{my_creds_fpath}" unless my_creds =~ %r{\A[^:]+:}

    @authorization = "Basic #{Base64.strict_encode64(my_creds)}"
  end

  def get(path)
    response = @rest.get("#{@uri}/#{path}", {
      authorization: @authorization,
      accept: :json
    })

    JSON.parse(response)
  end

  def get_cmdbi_record(clazz, sys_id)
    json = get("cmdb/instance/#{clazz}/#{sys_id}")
    result = json['result']
    unless result and result['attributes'] and result['outbound_relations'] and result['inbound_relations']
      Puppet.debug(result)
      raise RuntimeError, "The ServiceNow API was successful, but did not contain a complete result. See the --debug log."
    end

    result
  end
end
