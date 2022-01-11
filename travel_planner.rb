require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

require 'yaml'
require 'date'

require 'pry'

require_relative 'journey_classes'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

helpers do
  def navigation_breadcrumbs
    route = request.path
    return nil if route.length == 1
    # return [['Home', '/']] if route.match?(/\A\/[a-z]+\/\d+\z/)

    names = navigation_breadcrumb_names(route)
    paths = navigation_breadcrumb_paths(route)
    
    names.zip(paths)
  end

  def navigation_breadcrumb_names(route)
    instances = []
    ids = route.scan(/\d+/)
    ids.pop unless route.include?('add_')

    instances << journey = load_journey(ids.shift) unless ids.empty?
    instances << country = load_country(journey, ids.shift) unless ids.empty?
    instances << location = load_location(country, ids.shift) unless ids.empty?

    instances.map(&:name).prepend("Home")
  end

  def navigation_breadcrumb_paths(path)
    path = path.clone # Not necessary atm because I don't use `path` again.
    paths = []
    paths << path.slice!(0)

    while path.match? /\/.+\/\D/
      paths << paths.last + path.slice!(/\A.+?\d+/)
    end

    paths
  end
end

def data_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def load_journeys
  Dir.glob(File.join(data_path, '*')).map do |file|
    YAML.load_file(file)
  end
end

def invalid_route_guard(params)
  invalid_journey_guard(params)
  invalid_country_guard(params) if params[:country_id]
  invalid_location_guard(params) if params[:location_id]
end

def invalid_journey_guard(params)
  id = params[:journey_id].to_i
  if load_journeys.none? { |journey| journey.id == id }
    session[:message] = "The journey specified doesn't exist."
    redirect "/"
  end
end

def invalid_country_guard(params)
  journey = load_journey(params[:journey_id])
  id = params[:country_id].to_i
  if journey.countries.none? { |country| country.id == id }
    session[:message] = "The country specified doesn't exist."
    redirect "/journeys/#{journey.id}"
  end
end

def invalid_location_guard(params)
  journey = load_journey(params[:journey_id])
  country = load_country(journey, params[:country_id])

  id = params[:location_id].to_i
  if country.locations.none? { |location| location.id == id }
    session[:message] = "The location specified doesn't exist."
    redirect "/journeys/#{journey.id}/countries/#{country.id}"
  end
end

get "/" do
  @journeys = load_journeys
  erb :home
end

get "/create_journey" do
  erb :create_journey
end

post "/create_journey" do
  @journey_name = params[:journey_name].strip

  if invalid_journey_name?(@journey_name)
    status 422
    session[:message] = message_for_invalid_journey_name(@journey_name)
    erb :create_journey
  else
    create_journey(@journey_name)

    session[:message] = "Successfully created #{@journey_name}!"
    redirect "/"
  end
end

def invalid_journey_name?(input_name)
  input_name.empty? ||
  invalid_name_chars?(input_name) ||
  name_in_use?(input_name)
end

def invalid_name_chars?(input_name)
  !input_name.match?(/\A[a-z0-9\ _-]+\z/i)
end

def name_in_use?(input_name)
  journey_names.any? do |journey_name|
    Journey.camel_casify(journey_name) == Journey.camel_casify(input_name)
  end
end

def journey_names
  load_journeys.map(&:name)
end

def message_for_invalid_journey_name(name)
  case
  when name.empty?
    "A name for the journey must be supplied."
  when invalid_name_chars?(name)
    "Journey name must be constructed with alphanumerics, whitespace," \
    " hyphens, and underscores only."
  when name_in_use?(name)
    "That name is already in use for another journey, please choose another."
  end
end

def create_journey(journey_name)
  journey = Journey.new(journey_name)
  save_journey(journey)
end

def save_journey(journey)
  journey_path = File.join(data_path, "#{journey.camel_case_name}.yml")
  File.write(journey_path, Psych.dump(journey))
end

get "/journeys/:journey_id" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  render_page_with_details(@journey, :journey)
end

def load_journey(id)
  id = id.to_i
  load_journeys.find { |journey| journey.id == id }
end

def render_page_with_details(subject, template)
  @subject = subject
  erb :details_layout, :layout => :layout do
    erb template
  end
end

get "/journeys/:journey_id/add_country" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  erb :add_country
end

post "/journeys/:journey_id/add_country" do
  @journey = load_journey(params[:journey_id])

  params.each_value(&:strip!)
  @country = params[:country]
  @location = params[:location]
  @arrival_date = params[:arrival_date]

  if invalid_new_country?(params)
    status 422
    session[:message] = message_for_invalid_new_country(params)
    erb :add_country
  else
    add_country(@journey, @country, @location, @arrival_date)

    session[:message] = "#{@journey.name} now includes travels through #{@country}!"
    redirect parent_route
  end
end

def add_country(journey, country, location, arrival_date)
  added_c = journey.add_country(country)
  added_l = added_c.add_location(location)
  added_l.set_arrival_date(arrival_date)

  save_journey(journey)
end

def parent_route
  request.path[/\A.*(?=\/)/]
end

def invalid_new_country?(inputs)
  any_empty?(inputs) || invalid_date_format?(inputs[:arrival_date])
end

def invalid_date_format?(input_date)
  begin
    Date.strptime(input_date, "%d-%m-%Y")
  rescue Date::Error
    true
  else
    false
  end
end

def any_empty?(inputs)
  inputs.any? { |_, input| input.empty? }
end

def message_for_invalid_new_country(inputs)
  case
  when any_empty?(inputs)
    "Please make sure an entry has been supplied in each field."
  when invalid_date_format?(inputs[:arrival_date])
    "Invalid date: Please be sure to follow the specified format: <b>dd-mm-yyyy</b>"
  end
end

get "/journeys/:journey_id/add_details" do
  invalid_journey_guard(params)

  @journey = load_journey(params[:journey_id])
  @subject = @journey
  erb :add_details
end

post "/journeys/:journey_id/add_details" do
  journey = load_journey(params[:journey_id])
  journey.set_details(params[:details])
  journey.set_pros(params[:pros])
  journey.set_cons(params[:cons])

  save_journey(journey)

  redirect parent_route
end

get "/journeys/:journey_id/countries/:country_id" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])

  render_page_with_details(@country, :country)
end

def load_country(journey, id)
  id = id.to_i
  journey.countries.find { |c| c.id == id }
end

get "/journeys/:journey_id/countries/:country_id/add_location" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  
  erb :add_location
end

post "/journeys/:journey_id/countries/:country_id/add_location" do
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])

  params.each_value(&:strip!)
  @location = params[:location]
  @arrival_date = params[:arrival_date]

  if invalid_new_location?(params)
    status 422
    session[:message] = message_for_invalid_new_location(params)
    erb :add_location
  else
    add_location(@journey, @country, @location, @arrival_date)
    
    session[:message] = "Travels in #{@country.name} now include time spent in #{@location}!"
    redirect parent_route
  end
end

def add_location(journey, country, location, arrival_date)
  added_l = country.add_location(location)
  added_l.set_arrival_date(arrival_date)

  save_journey(journey)  
end

def invalid_new_location?(inputs)
  invalid_new_country?(inputs)
end

def message_for_invalid_new_location(inputs)
  message_for_invalid_new_country(inputs)
end

get "/journeys/:journey_id/countries/:country_id/locations/:location_id" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  @location = load_location(@country, params[:location_id])
  render_page_with_details(@location, :location)
end

def load_location(country, id)
  id = id.to_i
  country.locations.find { |l| l.id == id}
end

get "/journeys/:journey_id/countries/:country_id/locations/:location_id/add_accomodation" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  @location = load_location(@country, params[:location_id])
  erb :add_accomodation
end

post "/journeys/:journey_id/countries/:country_id/locations/:location_id/add_accomodation" do
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  @location = load_location(@country, params[:location_id])

  params.each_value(&:strip!)
  # @accomodation_name = params[:name]
  # @arrival_date = params[:arrival_date]

  # if invalid_new_accomodation?(params)
  #   status 422
  #   session[:message] = message_for_invalid_new_accomodation(params)
  #   erb :add_accomodation
  # else
    add_accomodation(@journey, @country, @location, params)
    
    session[:message] = "Travels in #{@country.name} now include time spent in #{@location}!"
    redirect parent_route
  # end
end

def add_accomodation(journey, country, location, params)
  added_acc = location.add_accomodation(params[:name])
  added_acc.set_address(params[:address])
  added_acc.set_cost(params[:cost])
  added_acc.set_arrival_date(params[:starting_date])
  added_acc.set_departure_date(params[:ending_date]) if params[:ending_date]
  added_acc.set_check_in_time(params[:check_in_time])
  added_acc.set_check_out_time(params[:check_out_time])
  added_acc.set_booking_service(params[:booking_service])
  added_acc.set_rating(params[:rating])

  save_journey(journey)  
end

get "/journeys/:journey_id/countries/:country_id/locations/:location_id/add_activity" do
  invalid_route_guard(params)

  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  @location = load_location(@country, params[:location_id])
  erb :add_activity
end

post "/journeys/:journey_id/countries/:country_id/locations/:location_id/add_activity" do

end

def add_activity(journey, country, location, params)
  added_act = location.add_activity(params[:name])
  added_act.set_starting_address(params[:starting_address])
  added_act.set_ending_address(params[:ending_address]) if params[:ending_address]
  added_act.set_starting_date(params[:starting_date])
  added_act.set_ending_date(params[:ending_date]) if params[:ending_date]
  
  added_act.set_cost(params[:cost])

  added_act.set_starting_time(params[:starting_time])
  added_act.set_ending_time(params[:ending_time])
  added_act.set_rating(params[:rating])
  added_act.set_to_bring(params[:to_bring])

  save_journey(journey)  
end