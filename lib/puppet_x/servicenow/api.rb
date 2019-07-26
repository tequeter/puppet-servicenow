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

  def initialize(uri)
    @uri = uri
    #parsed_uri = uri.match(uri_regexp_string)
    #unless parsed_uri
    #  raise ArgumentError, "Invalid ServiceNow URI #{uri}, expected https://user:pass@yourcompany.service-now.com"
    #end

    #scheme, @user, @password, rest = parsed_uri
    #@uri = scheme + rest
  end

  def get_cmdbi_record(clazz, sys_id)
    #encoded_user_pass = Base64.strict_encode64("#{@user}:#{@password}")
    response = RestClient.get("#{@uri}/api/now/cmdb/instance/#{clazz}/#{sys_id}", {
    #  authorization: "Basic #{encoded_user_pass}",
      accept: :json
    })

    json = JSON.parse(response)
    result = json['result']
    unless result and result['attributes'] and result['outbound_relations'] and result['inbound_relations']
      Puppet.debug(response)
      raise RuntimeError, "The ServiceNow API was successful, but did not contain a complete result. See the --debug log."
    end

    result
  end
end
