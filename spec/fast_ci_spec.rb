# frozen_string_literal: true

RSpec.describe FastCI do
  before do
    ENV["BUILD_ID"] = "fake_build_id#{rand(100_000).to_i}"
    ENV["FAST_CI_API_URL"] = "localhost:4000"
    ENV["FAST_CI_DEBUG"] = "yes"
    ENV["FAST_CI_SECRET_KEY"] = "test"
    FastCI.configuration.reset
  end

  describe ".configure" do
    specify do
      expect { FastCI.configuration.run_key }.to raise_error("#run_key was not configured.")

      FastCI.configure do |c|
        c.run_key = "rspec"
      end

      expect(FastCI.configuration.run_key).to eq "rspec"
    end
  end

  specify "Integration sample" do
    FastCI.configure do |c|
      c.run_key = "rspec"
    end

    tests = { "file1" => {}, "file2" => {}, "file3" => {}, "file4" => {} }

    FastCI.ws.on(:enq_request) do
      # Needs to return a list of tests to be sent to the API
      tests
    end

    runner = double

    tests.each do |file, _data|
      expect(runner).to receive(:run).with(file)
    end

    FastCI.ws.on(:deq) do |tests|
      # This block will be executed whenever the current node receives a subset
      # of tests to run
      results = {}
      tests.each do |test|
        runner.run(test)
        results[test] = { "run_time" => 1, "status" => "passed" }
      end
      results
    end

    FastCI.await
  end

  it "has a version number" do
    expect(FastCI::VERSION).not_to be nil
  end
end
