require "rubygems"
require "pathname"
require "test/unit"
require (Pathname(__FILE__).dirname.parent + "lib/port_authority").expand_path
require "do_sqlite3"
require "harbor/test/test"

DataMapper.setup :default, "sqlite3::memory:"
