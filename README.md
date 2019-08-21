# servicenow

## Description

Access ServiceNow from the Puppet ecosystem (Hiera, Bolt).

Features:

* Read from the CMDB with `lookup()` (eg. in Puppet manifests or Hiera data).
* Read from and update the CMDB through tasks.
* Create, read from and update common objects like incidents and change
  requests through tasks.

The tasks interface makes it easy to write Bolt plans that perform deploys
and report back to ServiceNow.

## Setup

### Setup Requirements

This module has a few external gem and Puppet modules dependencies.

1. `contain servicenow::server_prerequisites` somewhere in the profile of your
   Puppet server node, this will install the required gems for Hiera.
2. Run `/opt/puppetlabs/bolt/bin/gem install --user-install rest-client
   rschema`, this will install the required gems for Bolt.
3. Install the `puppetlabs/ruby_task_helper` module (eg. through your
   Puppetfile), for Bolt.

### Credentials File

The credentials used to connect to your ServiceNow instance are stored in a
separate file so that you may protect it with filesystem permissions and keep
it out of source control, especially for Hiera.

For instance, create `/etc/mycompany.service-now.com.yaml` similar to:

```yaml
---
url: https://mycompany.service-now.com
user: myusername
password: mypassword
```

The exact file name and location does not matter, just adapt the next examples
accordingly.

Make sure it is readable (only) by the Puppet Server and whoever runs Bolt:

```shell
chmod 600 /etc/mycompany.service-now.com.yaml
chown puppet:puppet /etc/mycompany.service-now.com.yaml
```

### Hiera Configuration

Alter your `hiera.yaml` to include a hierarchy level like:

```yaml
hierarchy:
# - ...
  - name: "ServiceNow CMDB"
    lookup_key: servicenow_cmdbi_lookup_attribute
    path: /etc/mycompany.service-now.com.yaml
# - ...
```

### Bolt Inventory

Add a node in your inventory file (eg. `~/.puppetlabs/bolt/inventory.yaml`)
like:

```yaml
nodes:
# - ...
  - name: mycompany.service-now.com
    config:
      transport: remote
      remote:
        servicenow_config_path: /etc/mycompany.service-now.com.yaml
# - ...
```

## Important ServiceNow concepts

### Table and Class Names

ServiceNow objects have types. Knowing the type of an object is essential to
access it and/or all of its properties.

The type is called `table` for Table Records (common objects like Change
Requests and Incidents), and `class` for CMDB CIs.

To interact with ServiceNow, you will need the technical type names, not the
human-friendly label displayed in the UI. For example, `change_request` instead
of `Change Request` and `cmdb_ci_appl` instead of `Application`.

You can find the technical name in the UI:

* Either by right click > Configure > Table as an Admin user.
* Or by looking hard enough at the URI, as any user. For example,
  `.../nav_to.do?uri=%2Fincident.do%3F...` means the table name is `incident`.

### `sys_id`

Access to all ServiceNow objects requires knowing their `sys_id`, a random 32
hexadecimal chars string. The human-friendly INC0123456 number (for Table
Records) cannot be used directly.

You can find the `sys_id` in the UI:

* Either by right click > Copy `sys_id` as an Admin user.
* Or again in the URI as any user. For example,
  `...%3Fsys_id%3D85aca49fdb5373002920553c689619cd%26...` means the `sys_id` is
  `85aca49fdb5373002920553c689619cd`.

## Usage

### Looking Up an Application's Version in the CMDB with Hiera

#### In a Hiera YAML File

```yaml
profile_myapp::version: "%{lookup('servicenow::cmdbi::cmdb_ci_appl::by_sys_id::6ed461b5dbaf13c4a38b9637db961996::version')}"
```

This is the preferred approach for production. It hides the ugly `sys_id` in a
configuration file where it belongs, and your Puppet code can just keep doing
automatic parameter lookups and type-check the values that users have entered
in the CMDB.

#### In a Puppet Manifest

```puppet
$app_version = lookup("servicenow::cmdbi::cmdb_ci_appl::by_sys_id::6ed461b5dbaf13c4a38b9637db961996::version")
notify { "version: ${app_version}": }
```

Prefer the Hiera version above.

#### From the CLI

```
puppet lookup --environment work servicenow::cmdbi::cmdb_ci_appl::by_sys_id::6ed461b5dbaf13c4a38b9637db961996::version
```

Useful for testing.

### Looking Up an Application's Version in the CMDB with Bolt

```
bolt task run servicenow::get_cmdbi_record \
  -t mycompany.service-now.com \
  class=cmdb_ci_appl \
  sys_id=6ed461b5dbaf13c4a38b9637db961996 \
  attribute=version
```

### Changing an Application's Version in the CMDB with Bolt

```
bolt task run servicenow::update_cmdbi_record \
  -t mycompany.service-now.com \
  class=cmdb_ci_appl \
  sys_id=6ed461b5dbaf13c4a38b9637db961996 \
  attributes='{"version": "1.2.3"}'
```

### Adding Work Notes on a Change Request with Bolt

```
bolt task run servicenow::update_table_record \
  -t mycompany.service-now.com \
  table=change_request \
  sys_id=95980405dbd8af4027effe9b0c9619ec \
  attributes='{"work_notes":"Hello from Bolt"}'
```

### Reporting an Incident with Bolt

```
bolt task run servicenow::create_table_record \
  -t mycompany.service-now.com \
  table=incident \
  attributes=''{"short_description":"Test from Bolt", "caused_by": "95980405dbd8af4027effe9b0c9619ec"}'
```

The task returns the `sys_id` of the incident as well as its number.

### Chaining Tasks in a Plan

See the provided `servicenow::test_*` plans.

## Reference

See [REFERENCE.md](REFERENCE.md).

## Troubleshooting

### "No suitable implementation" in Bolt

```
$ bolt task run servicenow::get_table_attribute -t mycompan.service-now.com ...
Started on mycompan.service-now.com...
Failed on mycompan.service-now.com:
  No suitable implementation of servicenow::get_table_attribute for mycompan.service-now.com
Failed on 1 node: mycompan.service-now.com
```

Check the node name and/or its definition in the Bolt inventory. In this
example, there is a typo in the node name so Bolt cannot find the associated
node definition.

### "Function lookup() did not find a value for ..."

- Make sure the CI class and `sys_id` are correct.
- Troubleshoot it with `puppet lookup` (see the example above). First add
  `--explain`, and if necessary the `--debug` option.
- You'll see both the URL of the REST API call and the JSON result in the
  `--debug` output. You can try that URL in your browser.

## Security

### User-Supplied Values in Hiera

Most Puppet modules do not properly protect against shell injection if a
unauthorized user can supply arbitrary class or resource parameters (see
[PUP-7891](https://tickets.puppetlabs.com/browse/PUP-7891)).

If your users can alter the CMDB but are not allowed to execute arbitrary
commands on your systems, you *must* type-check the values you get from
ServiceNow. If it is supposed to be a version, use a `Pattern` to ensure it
only holds characters in the `[0-9.]` range etc.

### Credentials File

Make sure the credentials file is not world-readable.

## Limitations

### Room for Improvement

This module implements only a tiny part of the exposed REST API. It should be
easy to extend as needed, though. See [Development](#development).

### Won't Do

This module purposely does not expose ServiceNow features through regular
Puppet functions:

- Values can be looked up through `lookup()`.
- Puppet code must not modify ServiceNow objects, as it would confuse the Hiera
  value cache accessed during the same Puppet run.

Likewise, ServiceNow is not allowed to expose values at arbitrary Hiera keys,
but only under `servicenow::...`. Someone with access to the Hiera files will
have to add the `%{lookup()}` calls where user-supplied values is desired
and expected. See [Security](#security).

### Missing Tests

- The lookup function is not unit-tested because Puppet does not seem to
  provide an easy way to do so.
- There are no integration tests. It would require setting up a mock ServiceNow
  API.
- The end-to-end tests are ran manually as they require some setup.

## Development

Standard community module practices apply (submit PRs, make sure you keep the tests
up to date etc.).

Make sure to run the end-to-end tests, on a ServiceNow development instance you
have access to.

```
bolt plan run servicenow::test_cmdbi_ru -t mydev.service-now.com
bolt plan run servicenow::test_table -t mydev.service-now.com
```

## Credits

Okaidi SAS sponsored the development of this module. Okaidi and Obaibi offer
original and quality clothing for babies and children aged 0 to 14 at
affordable prices.

Thomas Equeter wrote this module.
