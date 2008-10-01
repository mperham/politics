require 'echoe'

require File.dirname(__FILE__) << "/lib/politics/version"

Echoe.new 'politics' do |p|
  p.version = Politics::Version::STRING
  p.author = "Mike Perham"
  p.email  = 'mperham@gmail.com'
  p.project = 'politics'
  p.summary = "Algorithms and Tools for Distributed Computing in Ruby."
  p.url = "http://github.com/mperham/politics"
  p.dependencies = %w(memcache-client)
  p.development_dependencies = []
  p.include_rakefile = true
  p.rubygems_version = nil
end


require 'rake/testtask'

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs << ['test', 'lib']
	t.test_files = FileList['test/*_test.rb']
end

task :default => :test
