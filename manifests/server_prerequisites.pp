class servicenow::server_prerequisites {

  ensure_packages('gcc')

  [ 'json', 'rest-client' ].each |$_pkg| {
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
