# Installs the packages/gems required to make the server-side ServiceNow API
# work.
class servicenow::server_prerequisites {

  ensure_packages('gcc')

  [ 'rest-client', 'rschema' ].each |$_pkg| {
    [ 'puppet', 'puppetserver' ].each |$_store| {
      package { "${_pkg}-${_store}-gem":
        ensure   => present,
        name     => $_pkg,
        provider => "${_store}_gem",
        require  => Package['gcc'],
      }
    }
  }
}
