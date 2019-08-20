# Exposes a `servicenow::cmdbi::...` namespace to lookup ServiceNow CMDB
# class instance attributes from Hiera (cmdbi as in instance, versus metadata).
#
# The only supported format for now is:
# `servicenow::cmdbi::<class>::by_sys_id::<sys_id>::<attribute>`
#
# with `<class>` the technical name (for example cmdb_ci_appl, not
# Applications), `<sys_id>` the internal 32 chars GUID, and `<attribute>` the
# technical name of the attribute. Most technical stuff can be figured out from
# ServiceNow URLs.
#
# The Hiera entry looks like:
#
# ```yaml
# # ...
# hierarchy:
#   - name: "ServiceNow CMDB"
#     uri: "https://mycompany.service-now.com
#     lookup_key: servicenow_cmdbi_lookup_attribute
#     options:
#       path: /etc/servicenow_credentials.yaml
# # - ...
# ```
#
# The Hiera options must contain a path-like configuration (path, paths, glob,
# globs, although it's unlikely you'll ever need more than "path"). That path
# must point to a YAML file like:
#
# ```yaml
# ---
# url: https://mycompany.service-now.com
# user: user
# password: password
# ```
#
# The file and its password entry should be protected by filesystem
# permissions.
Puppet::Functions.create_function(:servicenow_cmdbi_lookup_attribute) do
  require_relative '../../puppet_x/servicenow/api'

  # @param key Key in format
  # `servicenow::cmdbi::<class>::by_sys_id::<sys_id>::<attribute>`. Anything
  # else is ignored to let your YAML etc. backends resolve it.
  # @param options Hiera options. Must contain a `path`-like entry.
  # @param context Standard argument.
  # @return [Any] The (possibly cached) attribute. A String or some more complex
  # datastructure, depending on your CMDB schema.
  dispatch :servicenow_cmdbi_lookup_attribute do
    param 'Variant[String, Numeric]', :key
    # Cannot validate here, unrelated options can get mixed in, such as eyaml
    # pkcs7_... from a "default" block.
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def servicenow_cmdbi_lookup_attribute(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    unless key.start_with?('servicenow::cmdbi::')
      context.explain { "servicenow_cmdbi_lookup_attribute: not looking up #{key} in ServiceNow as it does not start with servicenow::" }
      return context.not_found
    end

    parsed_key = key.match(%r{\Aservicenow::cmdbi::([^:]+)::by_sys_id::(\h{32})::([^:]+)\Z})
    unless parsed_key
      raise Puppet::DataBinding::LookupError, "servicenow_cmdbi_lookup_attribute: lookup key #{key}'s format is invalid"
    end
    clazz, sys_id, attribute = parsed_key.captures

    attributes = nil
    begin
      api = PuppetX::Servicenow::API.new(config_path: options['path'])
      record = api.get_cmdbi_record(clazz, sys_id)
      attributes = record['attributes']
    rescue StandardError => e
      raise Puppet::DataBinding::LookupError, "servicenow_cmdbi_lookup_attribute: error looking up #{key}: #{e}"
    end

    context.cache_all(attributes.transform_keys { |k| "servicenow::cmdbi::#{clazz}::by_sys_id::#{sys_id}::#{k}" })

    return context.not_found unless attributes.include?(attribute)

    attributes[attribute]
  end
end
