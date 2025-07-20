require 'test_helper'

class ApplicationJobTest < ActiveJob::TestCase
  test "inherits from ActiveJob::Base" do
    assert ApplicationJob < ActiveJob::Base
  end
  
  test "can be instantiated" do
    job = ApplicationJob.new
    assert_instance_of ApplicationJob, job
  end
end