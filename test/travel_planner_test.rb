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

  def create_journey(name)
    journey = Journey.new(name)
    save_journey(journey)
  end

  def save_journey(journey)
    File.write(File.join(data_path, "#{journey.camel_case_name}.yml"), Psych.dump(journey))
  end

  # def add_first_country(journey, country, location="Wellington", date="13-11-2012")
  #   j = load_journey(journey)
  #   add_initial_country(j, country, location, date)
  #   save_journey(j)
  # end

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
                                        " countries planned for visiting in your journey yet.</p>"
    assert_includes last_response.body, %q(<a href="/journeys/1/add_country">add your starting country?)
  end

  # COMMENTED OUT because the anchor's reference includes `New Zealand` in it's path. No point in
  # converting countries to camelcase only to have that feature replaced by indices

  # def test_visit_journey_page_with_countries
  #   create_journey('Foo Vacation')
  #   add_first_country('foo_vacation', 'New Zealand')

  #   get '/journeys/foo_vacation'

  #   assert_equal 200, last_response.status
  #   assert_includes last_response.body, "<h2>Countries</h2>"
  #   assert_includes last_response.body, %q(<a href="/journeys/foo_vacation/countries/New Zealand">New Zealand)
  # end

  # def test_visit_non_existent_journey_page

  # end
end