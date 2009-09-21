require "rubygems"
require "pathname"
require "rake"
require "spec/rake/spectask"

# Specs
task :default => :spec
Spec::Rake::SpecTask.new("spec") do |t|
  t.spec_opts << "--colour" << "--loadby" << "random"
  t.spec_files = Dir["spec/**/*_spec.rb"]
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
  s.add_dependency "harbor", ">= 0.12.8"
  s.add_dependency "ui", ">= 0.7.3"
  s.add_dependency "dm-core"
  s.add_dependency "dm-is-searchable"
  s.add_dependency "dm-validations"
  s.add_dependency "dm-timestamps"
  s.add_dependency "dm-aggregates"
  s.add_dependency "dm-types"
  s.add_dependency "tmail"
  s.add_dependency "faker"

end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Install Port Authority as a gem"
task :install => [:repackage] do
  sh %{gem install pkg/#{NAME}-#{GEM_VERSION}}
end