require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "should be an abstract class" do
    assert ApplicationRecord.abstract_class?
  end
  
  test "should inherit from ActiveRecord::Base" do
    assert ApplicationRecord < ActiveRecord::Base
  end
end