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

  def create_journey(name, country="New Zealand", city="Wellington")
    inputs = { name: name, country: country, city: city }
    File.write(File.join(data_path, name), Psych.dump(inputs))
  end

  def test_home_page_no_journeys
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>It looks like you haven't got any journeys planned right now..."
    assert_includes last_response.body, %q(<a href="/create_journey">create a new one?</a>)
  end

  def test_home_page_with_journeys
    create_journey('journey_to_atlantis')

    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Journeys</h2>"
    assert_includes last_response.body, ""
  end
end