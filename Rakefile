require 'rake/rdoctask'
require 'rake/testtask'

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs << ['test', 'lib']
  t.test_files = FileList['test/*_test.rb']
end

desc "Create rdoc"
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "History.rdoc", "lib/**/*.rb")
end


task :default => :test
