# Exposes a servicenow::cmdbi::... namespace to lookup ServiceNow CMDB
# class instance attributes from Hiera (cmdbi as in instance, versus metadata).
#
# The only supported format for now is:
# servicenow::cmdbi::<class>::by_sys_id::<sys_id>::<attribute>
#
# with <class> the technical name (for example cmdb_ci_appl, not Applications),
# <sys_id> the internal 32 chars GUID, and <attribute> the technical name of
# the attribute. Most technical stuff can be figured out from ServiceNow URLs.
Puppet::Functions.create_function(:servicenow_cmdbi_lookup_attribute) do
  require_relative '../../puppet_x/servicenow/api'

  dispatch :servicenow_cmdbi_lookup_attribute do
    param 'Variant[String, Numeric]', :key
    # Cannot validate here, unrelated options can get mixed in, such as eyaml
    # pkcs7_... from a "default" block.
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def servicenow_cmdbi_lookup_attribute(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    unless key =~ %r{\Aservicenow::cmdbi::}
      context.explain { "servicenow_cmdbi_lookup_attribute: not looking up #{key} in ServiceNow as it does not start with servicenow::" }
      return context.not_found()
    end

    parsed_key = key.match(%r{\Aservicenow::cmdbi::([^:]+)::by_sys_id::(\h{32})::([^:]+)\Z})
    unless parsed_key
      raise Puppet::DataBinding::LookupError, "servicenow_cmdbi_lookup_attribute: lookup key #{key}'s format is invalid"
    end
    clazz, sys_id, attribute = parsed_key.captures

    attributes = nil
    begin
      api = PuppetX::Servicenow::API.new(options['uri'])
      record = api.get_cmdbi_record(clazz, sys_id)
      attributes = record['attributes']
    rescue StandardError => e
      raise Puppet::DataBinding::LookupError, "servicenow_cmdbi_lookup_attribute: error looking up #{key}: #{e}"
    end

    context.cache_all(attributes.transform_keys {|k| "servicenow::cmdbi::#{clazz}::by_sys_id::#{sys_id}::#{k}" })

    if attributes.include?(attribute)
      return attributes[attribute]
    else
      return context.not_found()
    end
  end
end
