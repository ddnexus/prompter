name = File.basename( __FILE__, '.gemspec' )
version = File.read(File.expand_path('../VERSION', __FILE__)).strip
require 'date'

Gem::Specification.new do |s|

  s.authors = ["Domizio Demichelis"]
  s.email = 'dd.nexus@gmail.com'
  s.homepage = "http://github.com/ddnexus/#{name}"
  s.summary = 'Makes your prompts easier to build and prettier to look'
  s.description = 'A few helpers to create colored, multistep and hierarchical wizards'

  s.add_runtime_dependency('colorer', [">= 0.7.0"])
  s.add_runtime_dependency('yard', [">= 0.6.3"])
  s.add_development_dependency('irt', [">= 1.0.9"])

  s.files = `git ls-files -z`.split("\0")

  s.name = name
  s.version = version
  s.date = Date.today.to_s

  s.required_rubygems_version = ">= 1.3.6"
  s.has_rdoc = 'yard'
  s.require_paths = ["lib"]

end
