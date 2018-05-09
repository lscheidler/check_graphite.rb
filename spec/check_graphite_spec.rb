require "spec_helper"

describe CheckGraphite do
  it "has a version number" do
    expect(CheckGraphite::VERSION).not_to be nil
  end

  # TODO mock graphite web responses
  # TODO check output of check_graphite
end
