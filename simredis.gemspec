# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{simredis}
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Peter Cooper"]
  s.date = %q{2010-05-16}
  s.description = %q{Redis 'simulator' that allows you to use redis-rb without a Redis daemon running. Useful in situations where you want to deploy basic Redis-based apps quickly or to people who haven't got the ability to set up the Redis daemon.}
  s.email = %q{simredis@peterc.org}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/simredis.rb",
     "simredis.gemspec"
  ]
  s.homepage = %q{http://github.com/peterc/simredis}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Redis 'simulator' that allows you to use redis-rb without a Redis daemon running}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

