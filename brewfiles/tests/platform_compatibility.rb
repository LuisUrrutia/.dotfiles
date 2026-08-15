#!/usr/bin/env ruby

CORE_BREWFILE = File.expand_path("../core", __dir__)

class FakeMacOSVersion
  def initialize(name)
    @name = name
  end

  def >=(other)
    @name == :tahoe || other != :tahoe
  end

  def <(other)
    !self.>=(other)
  end
end

module MacOS
  class << self
    attr_accessor :fixture_version

    def version
      FakeMacOSVersion.new(fixture_version)
    end
  end
end

def tap(*)
  nil
end

def brew(*)
  nil
end

def vscode(*)
  nil
end

def cask(name, *)
  $captured_casks << name if name.include?("raycast")
end

def raycast_casks_for(version)
  MacOS.fixture_version = version
  $captured_casks = []
  load CORE_BREWFILE
  $captured_casks
end

unless raycast_casks_for(:sequoia) == ["raycast"]
  warn "platform compatibility test: pre-Tahoe macOS did not select stable Raycast"
  exit 1
end

unless raycast_casks_for(:tahoe) == ["LuisUrrutia/tap/raycast@beta"]
  warn "platform compatibility test: Tahoe did not select the Raycast beta"
  exit 1
end

puts "platform compatibility test: passed"
