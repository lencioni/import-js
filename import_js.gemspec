require './lib/import_js/version'

Gem::Specification.new do |s|
  s.name        = 'import_js'
  s.version     = ImportJS::VERSION
  s.date        = '2015-11-15'
  s.summary     = 'Import-JS'
  s.description = 'A tool to simplify importing javascript modules'
  s.authors     = ['Henric Trotzig']
  s.email       = 'henric.trotzig@gmail.com'
  s.files       = Dir['lib/**/*']
  s.executables = ['import-js']
  s.homepage    = 'http://rubygems.org/gems/import_js'
  s.license     = 'MIT'
  s.add_runtime_dependency 'slop', '~> 4.2', '>= 4.2.1'
end
