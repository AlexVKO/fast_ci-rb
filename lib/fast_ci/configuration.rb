# frozen_string_literal: true

module FastCI
  class Configuration
    attr_accessor :run_key, :build_id, :commit, :branch, :api_url, :secret_key

    def initialize
      # Settings defaults
      self.run_key = nil
      self.build_id = ENV.fetch("BUILD_ID")
      self.commit = `git rev-parse --short HEAD`.chomp
      self.branch = `git rev-parse --abbrev-ref HEAD`.chomp
      self.api_url = ENV["FAST_CI_API_URL"] || "api.fast.ci"
      self.secret_key = ENV.fetch("FAST_CI_SECRET_KEY")
    end

    def reset
      initialize
    end

    def run_key
      @run_key || raise("#run_key was not configured.")
    end
  end
end
