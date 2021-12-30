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

  def session
    last_request.env["rack.session"]
  end

  def add_country_for_tests(journey_name, country_name, location_name, arrival_date)
    journey = load_journeys.find { |journey| journey.name == journey_name }
    add_country(journey, country_name, location_name, arrival_date)
    save_journey(journey)
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

  def test_breadcrumb_navigation_at_create_journey_page
    create_journey "Foo Vacation"
    get "/create_journey"

    assert_includes last_response.body, %q(<a href="/">Home</a>)
    refute_includes last_response.body, %q(<a href="/journeys/1">Foo Vacation</a>)
  end

  def test_create_journey # <<< Test with whitespace -> "foo vacation"
    post "/create_journey", { journey_name: "Foo Vacation" }

    assert_equal 302, last_response.status
    assert_equal "Successfully created Foo Vacation!", session["message"]

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

  def test_breadcrumb_navigation_at_journey_page
    create_journey "Foo Vacation"
    get "/journeys/1"

    assert_includes last_response.body, %q(<a href="/">Home</a>)
    refute_includes last_response.body, %q(<a href="/journeys/1">Foo Vacation</a>)
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
    assert_equal "That journey doesn't exist", session[:message]
    
    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>It looks like you haven't got any journeys planned right now..."
  end

  def test_visit_add_country_page_first_country
    create_journey('Foo Vacation')

    get "/journeys/1/add_country"

    assert_equal 200, last_response.status

    assert_includes last_response.body, "<h2>Adding a Country..."
    assert_includes last_response.body, %q(<label for="country">Which country will you set out from?)
    assert_includes last_response.body, %q(<label for="location">From which location will you set out?)
    assert_includes last_response.body, %q(<label for="arrival_date">What date will you set out? (dd-mm-yyyy))
  end

  def test_visit_add_country_page_later_countries
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    get "/journeys/1/add_country"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Adding a Country..."
    assert_includes last_response.body, %q(<label for="country">Which country would you like to add to your journey?)
    assert_includes last_response.body, %q(<label for="location">Which location will you arrive in?)
    assert_includes last_response.body, %q(<label for="arrival_date">What date will you arrive? (dd-mm-yyyy))
  end

  def test_breadcrumb_navigation_at_add_country_page
    create_journey "Foo Vacation"
    get "/journeys/1/add_country"

    assert_includes last_response.body, %q(<a href="/">Home</a>)
    assert_includes last_response.body, %q(<a href="/journeys/1">Foo Vacation</a>)
  end

  def test_add_country
    create_journey('Foo Vacation')

    post "/journeys/1/add_country", { 
      country: 'New Zealand', location: 'Wellington', arrival_date: '13-11-1995'
    }

    assert_equal 302, last_response.status
    assert_equal "Foo Vacation now includes travels through New Zealand!", session[:message]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<li><a href="/journeys/1/countries/1">New Zealand)
  end

  def test_add_country_with_empty_input
    create_journey('Foo Vacation')

    post "/journeys/1/add_country", { 
      country: 'New Zealand', location: '    ', arrival_date: '    '
    }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please make sure an entry has been supplied in each field."

    assert_includes last_response.body, %q(<input name="country" value="New Zealand">)
    assert_includes last_response.body, %q(<input name="location" value="">)
    assert_includes last_response.body, %q(<input name="arrival_date" value="">)
  end

  def test_add_country_invalid_date_format
    create_journey('Foo Vacation')

    post "/journeys/1/add_country", { 
      country: 'New Zealand', location: 'Wellington', arrival_date: '0001-10-24'
    }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid date: Please be sure to follow the specified format: <b>dd-mm-yyyy</b>"

    assert_includes last_response.body, %q(<input name="country" value="New Zealand">)
    assert_includes last_response.body, %q(<input name="location" value="Wellington">)
    assert_includes last_response.body, %q(<input name="arrival_date" value="0001-10-24">)
  end

  def test_visit_country_page
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    get "/journeys/1/countries/1"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Locations</h2>"
    assert_includes last_response.body, %q(<li><a href="/journeys/1/countries/1/locations/1">Wellington)
  end

  def test_breadcrumb_navigation_at_country_page
    create_journey "Foo Vacation"
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")
    
    get "/journeys/1/countries/1"

    assert_includes last_response.body, %q(<a href="/">Home</a>)
    assert_includes last_response.body, %q(<a href="/journeys/1">Foo Vacation</a>)
    refute_includes last_response.body, %q(<a href="/journeys/1/countries/1">New Zealand</a>)
  end

  def test_visit_add_location_page
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    get "/journeys/1/countries/1/add_location"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h2>Adding a Location..."
    assert_includes last_response.body, %q(<label for="location">Where else would you like to visit during your time in New Zealand?)
    assert_includes last_response.body, %q(<label for="arrival_date">What date will you arrive there? (dd-mm-yyyy))
  end

  def test_breadcrumb_navigation_at_add_location_page
    create_journey "Foo Vacation"
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")
    
    get "/journeys/1/countries/1/add_location"

    assert_includes last_response.body, %q(<a href="/">Home</a>)
    assert_includes last_response.body, %q(<a href="/journeys/1">Foo Vacation</a>)
    assert_includes last_response.body, %q(<a href="/journeys/1/countries/1">New Zealand</a>)
  end

  def test_add_location
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    post "/journeys/1/countries/1/add_location", { location: 'Auckland', arrival_date: '13-11-2022' }

    assert_equal 302, last_response.status
    assert_equal "Travels in New Zealand now include time spent in Auckland!", session[:message]

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<li><a href="/journeys/1/countries/1/locations/2">Auckland)
  end

  def test_add_location_with_empty_input
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    post "/journeys/1/countries/1/add_location", { location: '    ', arrival_date: '13-11-2022' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please make sure an entry has been supplied in each field."
    assert_includes last_response.body, %q(<input name="location" value="">)
    assert_includes last_response.body, %q(<input name="arrival_date" value="13-11-2022">)
  end

  def test_add_location_invalid_date_format
    create_journey('Foo Vacation')
    add_country_for_tests("Foo Vacation", "New Zealand", "Wellington", "13-11-2022")

    post "/journeys/1/countries/1/add_location", { location: 'Auckland', arrival_date: '0001-01-30' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid date: Please be sure to follow the specified format: <b>dd-mm-yyyy</b>"
    assert_includes last_response.body, %q(<input name="location" value="Auckland">)
    assert_includes last_response.body, %q(<input name="arrival_date" value="0001-01-30">)
  end
end