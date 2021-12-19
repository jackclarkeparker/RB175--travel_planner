ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require 'fileutils'

require_relative "../travel_planner.rb"

class TravelPlannerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rmdir(data_path)
  end

  def test_journeys_page
    get "/" do
      assert_equal 200, last_response.status
      assert_includes last_response.body, ""
    end
  end
end