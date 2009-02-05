Gem::Specification.new do |s|
	s.name = "politics"
	s.version = "0.2.5"
	s.authors = "Mike Perham"
	s.email = "mperham@gmail.com"
	s.homepage = "http://github.com/mperham/politics/"
	s.summary = "Algorithms and Tools for Distributed Computing in Ruby."
	s.description = s.summary

	s.require_path = 'lib'

	# get this easily and accurately by running 'Dir.glob("{lib,examples}/**/*")'
	# in an IRB session.  However, GitHub won't allow that command hence
	# we spell it out.
	s.files = ["lib/init.rb", "lib/politics", "lib/politics/discoverable_node.rb", "lib/politics/static_queue_worker.rb", "lib/politics/token_worker.rb", "lib/politics/version.rb", "lib/politics.rb", "examples/queue_worker_example.rb", "examples/token_worker_example.rb"]
	s.test_files = ["test/static_queue_worker_test.rb", "test/test_helper.rb", "test/token_worker_test.rb"]
	s.has_rdoc = true
	s.rdoc_options = ["--quiet", "--title", "Politics documentation", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
	s.extra_rdoc_files = ["README.rdoc", "History.rdoc", "LICENSE"]

	s.add_dependency 'memcache-client', '>=1.5.0'
	s.add_dependency 'starling-starling', '>=0.9.8'
	s.add_dependency 'net-mdns', '>=0.4'
end
