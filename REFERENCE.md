# Reference
<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

**Classes**

* [`servicenow::server_prerequisites`](#servicenowserver_prerequisites): Installs the packages/gems required to make the server-side ServiceNow API work.

**Functions**

* [`servicenow_cmdbi_lookup_attribute`](#servicenow_cmdbi_lookup_attribute): Exposes a `servicenow::cmdbi::...` namespace to lookup ServiceNow CMDB class instance attributes from Hiera (cmdbi as in instance, versus met

**Data types**

* [`Servicenow::Sys_id`](#servicenowsys_id): Internal IDs used by ServiceNow on most objects

**Tasks**

* [`create_table_record`](#create_table_record): Create a new Table record (most ServiceNow objects), returns its attributes
* [`get_cmdbi_attribute`](#get_cmdbi_attribute): Get a single attribute from a CI or other CMDB instance record and return it in the "value" key. Not cached.
* [`get_cmdbi_record`](#get_cmdbi_record): Get a CI or other CMDB instance record and return it in the "attributes" and *relations key. Not cached.
* [`get_table_attribute`](#get_table_attribute): Get a single attribute from a Table record (most ServiceNow objects)
* [`get_table_record`](#get_table_record): Get a Table record (most ServiceNow objects) and return the hash of attributes
* [`update_cmdbi_record`](#update_cmdbi_record): Set attributes on a CI or other CMDB instance record
* [`update_table_record`](#update_table_record): Set attributes on a Table record (most ServiceNow objects)

**Plans**

* [`servicenow::test_cmdbi_ru`](#servicenowtest_cmdbi_ru): End-to-end test for CMDB Instance retrieve / update.
* [`servicenow::test_table`](#servicenowtest_table): End-to-end test for Table Record tasks.

## Classes

### servicenow::server_prerequisites

Installs the packages/gems required to make the server-side ServiceNow API
work.

## Functions

### servicenow_cmdbi_lookup_attribute

Type: Ruby 4.x API

Exposes a `servicenow::cmdbi::...` namespace to lookup ServiceNow CMDB
class instance attributes from Hiera (cmdbi as in instance, versus metadata).

The only supported format for now is:
`servicenow::cmdbi::<class>::by_sys_id::<sys_id>::<attribute>`

with `<class>` the technical name (for example cmdb_ci_appl, not
Applications), `<sys_id>` the internal 32 chars GUID, and `<attribute>` the
technical name of the attribute. Most technical stuff can be figured out from
ServiceNow URLs.

The Hiera options must contain a path-like configuration (path, paths, glob,
globs, although it's unlikely you'll ever need more than "path"). That path
must point to YAML-formatted credentials file. See the README for more
information.

#### `servicenow_cmdbi_lookup_attribute(Variant[String, Numeric] $key, Hash $options, Puppet::LookupContext $context)`

Exposes a `servicenow::cmdbi::...` namespace to lookup ServiceNow CMDB
class instance attributes from Hiera (cmdbi as in instance, versus metadata).

The only supported format for now is:
`servicenow::cmdbi::<class>::by_sys_id::<sys_id>::<attribute>`

with `<class>` the technical name (for example cmdb_ci_appl, not
Applications), `<sys_id>` the internal 32 chars GUID, and `<attribute>` the
technical name of the attribute. Most technical stuff can be figured out from
ServiceNow URLs.

The Hiera options must contain a path-like configuration (path, paths, glob,
globs, although it's unlikely you'll ever need more than "path"). That path
must point to YAML-formatted credentials file. See the README for more
information.

Returns: `Any` The (possibly cached) attribute. A String or some more complex

##### `key`

Data type: `Variant[String, Numeric]`

Key in format

##### `options`

Data type: `Hash`

Hiera options. Must contain a `path`-like entry.

##### `context`

Data type: `Puppet::LookupContext`

Standard argument.

## Data types

### Servicenow::Sys_id

Internal IDs used by ServiceNow on most objects

Alias of `Pattern[/\A\h{32}\Z/]`

## Tasks

### create_table_record

Create a new Table record (most ServiceNow objects), returns its attributes

**Supports noop?** false

#### Parameters

##### `table`

Data type: `String[1]`

Internal table name, for example incident

##### `attributes`

Data type: `Hash[String[1], Any]`

Initial attributes (field values) the Record should have.

### get_cmdbi_attribute

Get a single attribute from a CI or other CMDB instance record and return it in the "value" key. Not cached.

**Supports noop?** false

#### Parameters

##### `class`

Data type: `String[1]`

Class of the CI, determines the visible attributes

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the CI, visible in the browser's URL

##### `attribute`

Data type: `String[1]`

Which attribute to return, for example version

### get_cmdbi_record

Get a CI or other CMDB instance record and return it in the "attributes" and *relations key. Not cached.

**Supports noop?** false

#### Parameters

##### `class`

Data type: `String[1]`

Class of the CI, determines the visible attributes

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the CI, visible in the browser's URL

### get_table_attribute

Get a single attribute from a Table record (most ServiceNow objects)

**Supports noop?** false

#### Parameters

##### `table`

Data type: `String[1]`

Internal table name, for example change_request

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the record, visible in the browser's URL

##### `attribute`

Data type: `String[1]`

Which field to return, for example description

### get_table_record

Get a Table record (most ServiceNow objects) and return the hash of attributes

**Supports noop?** false

#### Parameters

##### `table`

Data type: `String[1]`

Internal table name, for example change_request

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the record, visible in the browser's URL

### update_cmdbi_record

Set attributes on a CI or other CMDB instance record

**Supports noop?** false

#### Parameters

##### `class`

Data type: `String[1]`

Class of the CI, determines the visible attributes

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the CI, visible in the browser's URL

##### `attributes`

Data type: `Hash[String[1], Any]`

What to update on that CI, for example {"version": "1.2.3"}

### update_table_record

Set attributes on a Table record (most ServiceNow objects)

**Supports noop?** false

#### Parameters

##### `table`

Data type: `String[1]`

Internal table name, for example change_request

##### `sys_id`

Data type: `Servicenow::Sys_id`

Unique ID of the record, visible in the browser's URL

##### `attributes`

Data type: `Hash[String[1], Any]`

What to update on that record, for example {"work_notes": "I did stuff"}

## Plans

### servicenow::test_cmdbi_ru

This test updates the attribute of an existing CI to a new value, ensure it
is as expected, and rolls back the change.

You'll need to provide a `sys_id` of an Application in your CMDB and a
`target_value` different from its current value.

#### Parameters

The following parameters are available in the `servicenow::test_cmdbi_ru` plan.

##### `nodes`

Data type: `TargetSpec`

Must match the ServiceNow entry in your inventory. Multiple nodes are not
supported.

##### `class`

Data type: `String[1]`

Internal ServiceNow class name for the CI.

Default value: 'cmdb_ci_appl'

##### `sys_id`

Data type: `Servicenow::Sys_id`

Internal ServiceNow identifier for an existing CI.

Default value: '6ed461b5dbaf13c4a38b9637db961996'

##### `attribute`

Data type: `String[1]`

CI attribute we'll test updating.

Default value: 'version'

##### `target_value`

Data type: `String[1]`

The value we'll set the attribute to.

Default value: '1.2.3'

### servicenow::test_table

This test:

1. Creates a new incident.
2. Updates its short description.
3. Verifies it is set as expected.

The incident is not deleted afterwards because the user running the test may
not have the right to do so. The test is not expected to be run on a
production ServiceNow instance.

#### Parameters

The following parameters are available in the `servicenow::test_table` plan.

##### `nodes`

Data type: `TargetSpec`

Must match the ServiceNow entry in your inventory. Multiple nodes are not
supported.

##### `table`

Data type: `String[1]`

Internal ServiceNow table name.

Default value: 'incident'

##### `attribute`

Data type: `String[1]`

Table attribute (field) we'll test updating.

Default value: 'short_description'

##### `target_value1`

Data type: `String[1]`

The value we'll set the attribute to at first.

Default value: 'Test from Bolt - init'

##### `target_value2`

Data type: `String[1]`

The value we'll set the attribute to when updating the record.

Default value: 'Test from Bolt - updated'

