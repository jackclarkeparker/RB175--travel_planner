ENV["RACK_ENV"] = 'test'

require 'minitest/autorun'
require 'rack/test'

require 'fileutils'

require_relative "../travel_planner"

class TravelPlannerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir(data_path)
  end

  def teardown
    FileUtils.rmtree(data_path)
    Journey.class_variable_set(:@@current_journeys, [])
  end

  def add_country_for_tests(journey_name, country_name, location_name, arrival_date)
    journey = load_journeys.find { |journey| journey.name == journey_name }
    add_country(journey, country_name, location_name, arrival_date)
    save_journey(journey)
  end

  def session
    last_request.env["rack.session"]
  end

  def test_visit_home_page_no_journeys
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>It looks like you haven't got any journeys planned right now..."
    assert_includes last_response.body, %q(<a href="/create_journey">create a new one?</a>)
  end

  def test_visit_home_page_with_journeys
    create_journey('Foo Vacation')

    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Journeys</h2>"
    assert_includes last_response.body, %q(<li><a href="/journeys/1">Foo Vacation)
  end

  def test_id_increments_with_multiple_journeys
    create_journey("Foo Vacation")
    create_journey("Bar Vacation")
    create_journey("Baz Vacation")

    get "/"

    assert_includes last_response.body, %q(<li><a href="/journeys/1">Foo Vacation)
    assert_includes last_response.body, %q(<li><a href="/journeys/2">Bar Vacation)
    assert_includes last_response.body, %q(<li><a href="/journeys/3">Baz Vacation)
  end

  def test_visit_create_journey_page
    get "/create_journey"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input name="journey_name" value="">)
    assert_includes last_response.body, %q(<button type="submit">Create New Journey)
  end

  def test_create_journey # <<< Test with whitespace -> "foo vacation"
    post "/create_journey", { journey_name: "Foo Vacation" }

    assert_equal 302, last_response.status
    assert_equal session["message"], "Successfully created Foo Vacation!"

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<li><a href="/journeys/1">Foo Vacation)
  end

  def test_create_journey_with_invalid_chars
    post "/create_journey", { journey_name: '../../hacking' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Journey name must be constructed with" \
                                        " alphanumerics, whitespace, hyphens, and underscores only."
    assert_includes last_response.body, %q(<input name="journey_name" value="../../hacking">)
  end

  def test_create_journey_with_existing_name
    create_journey('Foo Vacation')

    post "/create_journey", { journey_name: 'fOO vACATION' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "That name is already in use for another" \
                                        " journey, please choose another."
    assert_includes last_response.body, %q(<input name="journey_name" value="fOO vACATION">)
  end

  def test_create_journey_with_no_name
    post "/create_journey", { journey_name: '  ' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name for the journey must be supplied."
    assert_includes last_response.body, %q(<input name="journey_name" value="">)
  end

  def test_visit_journey_page_no_countries
    create_journey('Foo Vacation')

    get '/journeys/1'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>It looks like you don't have any" \
                                        " countries planned for a visit on this journey yet.</p>"
    assert_includes last_response.body, %q(<a href="/journeys/1/add_country">add your starting country?)
  end

  def test_visit_journey_page_with_countries
    create_journey('Foo Vacation')
    add_country_for_tests('Foo Vacation', 'New Zealand', 'Wellington', '13-11-1864')

    get '/journeys/1'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Countries</h2>"
    assert_includes last_response.body, %q(<a href="/journeys/1/countries/1">New Zealand)
  end

  def test_id_increments_with_multiple_countries
    create_journey('Foo Vacation')
    add_country_for_tests('Foo Vacation', 'New Zealand', 'Wellington', '13-11-1864')
    add_country_for_tests('Foo Vacation', 'Australia', 'Sydney', '14-11-1864')
    add_country_for_tests('Foo Vacation', 'Vietnam', 'Da Nang', '15-11-1864')

    get "/journeys/1"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Countries</h2>"
    assert_includes last_response.body, %q(<a href="/journeys/1/countries/1">New Zealand)
    assert_includes last_response.body, %q(<a href="/journeys/1/countries/2">Australia)
    assert_includes last_response.body, %q(<a href="/journeys/1/countries/3">Vietnam)
  end

  def test_visit_non_existent_journey_page
    get '/journeys/1'

    assert_equal 302, last_response.status
    assert_equal session[:message], "That journey doesn't exist"
    
    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>It looks like you haven't got any journeys planned right now..."
  end

  def test_visit_add_country_page_first_time
    create_journey('Foo Vacation')

    get "/journeys/1/add_country"


  end

  def test_visit_add_country_page_subsequent_times

  end

  def test_add_country

  end

  def test_add_country_with_empty_input

  end

  def test_add_country_invalid_date_format

  end

  def test_visit_country_page

  end

  def test_visit_add_location_page

  end

  def test_add_location

  end

  def test_add_location_with_empty_input

  end

  def test_add_location_invalid_date_format

  end

  def test_
end