#!/usr/bin/env ruby

require "lib/port_authority"
# View::cache_templates!

services = Harbor::Container.new
services.register("mailer", Harbor::Mailer)
services.register("mail_server", Harbor::MailServers::Sendmail)

logger = Logging.logger((Pathname(__FILE__).dirname + "log/app.log").to_s)
logger.level = ENV["LOG_LEVEL"] || :debug
services.register("logger", logger)

DataMapper.setup :default, "sqlite3://#{Pathname(__FILE__).dirname.expand_path + "users.db"}"
# DataMapper.setup :search, "ferret:///tmp/ferret_index.sock"

DataObjects::Sqlite3.logger = DataObjects::Logger.new(Pathname(__FILE__).dirname + "log/db.log", :debug)

UI.public_path = Pathname(__FILE__).dirname.expand_path + "lib" + "port_authority" + "public"

PortAuthority::is_searchable! if ENV['SEARCHABLE']
PortAuthority::use_lockouts!
PortAuthority::use_logins! if ENV['LOGINS']
Harbor::Mailer.host = "localhost:3000"
# PortAuthority.logger = logger

if $0 == __FILE__
  require "harbor/console"
  Harbor::Console.start
else
  run PortAuthority.new(services)
end
