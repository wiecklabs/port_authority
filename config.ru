#!/usr/bin/env ruby

require "lib/port_authority"

$services = Harbor::Container.new
$services.register("mailer", Harbor::Mailer)
$services.register("mail_server", Harbor::MailServers::Sendmail)

logger = Logging.logger((Pathname(__FILE__).dirname + "log/app.log").to_s)
logger.level = ENV["LOG_LEVEL"] || :info
$services.register("logger", logger)

DataMapper.setup :default, "sqlite3://#{Pathname(__FILE__).dirname.expand_path + "users.db"}"

DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, :info)

Harbor::View.layouts.map("admin/*", "layouts/admin")

UI.public_path = PortAuthority.public_path

PortAuthority::is_searchable! if ENV['SEARCHABLE']
PortAuthority::use_lockouts!
PortAuthority::use_logins! if ENV['LOGINS']
PortAuthority::use_approvals! if ENV['APPROVALS']
PortAuthority::admin_email_addresses = [ENV['ADMIN_EMAIL']].flatten if ENV['ADMIN_EMAIL']
Harbor::Mailer.host = "localhost:3000"
PortAuthority.logger = logger

if $0 == __FILE__
  require "harbor/console"
  Harbor::Console.start
elsif $0['thin'] || $0['Rack'] || $0['unicorn']
  run PortAuthority.new($services)
end