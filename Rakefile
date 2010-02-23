require "rubygems"
require "pathname"
require "rake"
require "rake/testtask"

task :default => :test

# Tests
Rake::TestTask.new do |t|
  t.test_files = 'test/**/*_test.rb'
end

# Gem
require "rake/gempackagetask"
require "lib/port_authority/version"

NAME = "port_authority"
SUMMARY = "Port Authority: User management port for Harbor"
GEM_VERSION = PortAuthority::VERSION

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.summary = s.description = SUMMARY
  s.homepage = "http://wiecklabs.com"
  s.author = "Wieck Media"
  s.email = "dev@wieck.com"
  s.homepage = "http://www.wieck.com"
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.files = %w(Rakefile) + Dir.glob("{lib,assets,public,test}/**/*")

  s.add_dependency "fastercsv"
  s.add_dependency "json"
  s.add_dependency "logging"
  s.add_dependency "harbor", ">= 0.12.11"
  s.add_dependency "ui", ">= 0.7.3"
  s.add_dependency "dm-core", "= 0.9.11"
  s.add_dependency "dm-is-searchable", "= 0.9.11"
  s.add_dependency "dm-validations", "= 0.9.11"
  s.add_dependency "dm-timestamps", "= 0.9.11"
  s.add_dependency "dm-aggregates", "= 0.9.11"
  s.add_dependency "dm-types", "= 0.9.11"
  s.add_dependency "mail_builder"
  s.add_dependency "tmail"
  s.add_dependency "faker"
  s.add_dependency "sanitize"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

spec_file = ".gemspec"
desc "Create #{spec_file}"
task :gemspec do
  File.open(spec_file, "w") do |file|
    file.puts spec.to_ruby
  end
end

desc "Install Port Authority as a gem"
task :install => [:repackage] do
  sh %{gem install pkg/#{NAME}-#{GEM_VERSION}}
end

task :version do
    puts GEM_VERSION
end