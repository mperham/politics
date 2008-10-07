Gem::Specification.new do |s|
	s.name = "politics"
	s.version = "0.1.0"
	s.authors = "Mike Perham"
	s.email = "mperham@gmail.com"
	s.homepage = "http://github.com/mperham/politics/"
	s.summary = "Algorithms and Tools for Distributed Computing in Ruby."
	s.description = s.summary

	s.require_path = 'lib'

	# get this easily and accurately by running 'Dir.glob("{lib,test}/**/*")'
	# in an IRB session.  However, GitHub won't allow that command hence
	# we spell it out.
	s.files = ["README.rdoc", "LICENSE", "History.rdoc", "Rakefile", "lib/init.rb", "lib/politics", "lib/politics/bucket_worker.rb", "lib/politics/discoverable_node.rb", "lib/politics/token_worker.rb", "lib/politics/version.rb", "lib/politics.rb"]
	s.test_files = ["test/bucket_worker_test.rb", "test/political_test.rb", "test/test_helper.rb", "test/token_worker_test.rb"]
	s.has_rdoc = true
	s.rdoc_options = ["--quiet", "--title", "Politics documentation", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
	s.extra_rdoc_files = ["README.rdoc", "History.rdoc", "LICENSE"]

	s.add_dependency 'fiveruns-memcache-client'
	s.add_dependency 'fiveruns-starling'
end
