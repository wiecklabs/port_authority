# PortAuthority

User management [port](http://www.wiecklabs.com/features#ports) for [Harbor](http://www.wiecklabs.com/)
applications

## Dependencies

  * [harbor](http://github.com/wiecklabs/harbor) (>= 0.15.1)
  * [ui](http://github.com/wiecklabs/ui) (>= 0.7.3)
  * fastercsv
  * json
  * logging
  * dm-core (= 0.9.11)
  * dm-is-searchable (= 0.9.11)
  * dm-validations (= 0.9.11)
  * dm-timestamps (= 0.9.11)
  * dm-aggregates (= 0.9.11)
  * dm-types (= 0.9.11)
  * tmail
  * faker
  * sanitize

## Try it out

  * git clone git://github.com/wiecklabs/port_authority.git
  * cd port_authority
  * bundle install
  * Run ./config.ru to start console
    * DataMapper.auto_upgrade!
    * PortAuthority.fake!
    * exit console
  * rackup
  * Go to http://localhost:9292/ and have fun!