# frozen_string_literal: true

require "spec_helper"

RSpec.describe FastCI::Configuration do
  describe "build_id, commit and branch" do
    it "works with RubyCI" do
      envs = {
        RUBYCI_SHA: "commit_from_ruby_ci",
        RUBYCI_BRANCH: "branch_from_ruby_ci",
        BUILD_ID: "1"
      }

      with_env_variables(envs) do
        instance = described_class.new

        expect(instance.commit).to eq("commit_from_ruby_ci")
        expect(instance.branch).to eq("branch_from_ruby_ci")
        expect(instance.build_id).to eq("1")
      end
    end

    it "works with Github Actions" do
      envs = {
        GITHUB_SHA: "commit_from_gh",
        GITHUB_REF: "branch_from_gh",
        GITHUB_RUN_ID: "2"
      }

      with_env_variables(envs) do
        instance = described_class.new

        expect(instance.commit).to eq("commit_from_gh")
        expect(instance.branch).to eq("branch_from_gh")
        expect(instance.build_id).to eq("2")
      end
    end

    it "works with CircleCI" do
      envs = {
        CIRCLE_SHA1: "commit_from_circle",
        CIRCLE_BRANCH: "branch_from_circle",
        CIRCLE_BUILD_NUM: "3"
      }

      with_env_variables(envs) do
        instance = described_class.new

        expect(instance.commit).to eq("commit_from_circle")
        expect(instance.branch).to eq("branch_from_circle")
        expect(instance.build_id).to eq("3")
      end
    end

    def with_env_variables(envs)
      ENV["FAST_CI_SECRET_KEY"] = "dummy"
      envs.each { |key, value| ENV[key.to_s] = value }
      yield
      envs.each { |key, _value| ENV[key.to_s] = nil }
      ENV["FAST_CI_SECRET_KEY"] = nil
    end
  end
end
