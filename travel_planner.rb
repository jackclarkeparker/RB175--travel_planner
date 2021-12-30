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
    ids = ids[0..-2] unless route.include?('add_')

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

# Move to a different location in the program? Where is it used?
def journey_names
  load_journeys.map(&:name)
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

def create_journey(journey_name)
  journey = Journey.new(journey_name)
  save_journey(journey)
end

def save_journey(journey)
  journey_path = File.join(data_path, "#{journey.camel_case_name}.yml")
  File.write(journey_path, Psych.dump(journey))
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

get "/journeys/:journey_id" do
  if nonexistent_journey?(params[:journey_id])
    session[:message] = "That journey doesn't exist"
    redirect "/"
  else
    @journey = load_journey(params[:journey_id])
    erb :journey
  end
end

def load_journey(id)
  id = id.to_i
  load_journeys.find { |journey| journey.id == id }
end

def nonexistent_journey?(id)
  id = id.to_i
  load_journeys.none? { |journey| journey.id == id }
end

get "/journeys/:journey_id/add_country" do
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

get "/journeys/:journey_id/countries/:country_id" do
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])

  erb :country
end

def load_country(journey, id)
  id = id.to_i
  journey.countries.find { |c| c.id == id }
end

get "/journeys/:journey_id/countries/:country_id/add_location" do
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  
  erb :add_location
end

post "/journeys/:journey_id/countries/:country_id/add_location" do
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])

  params.each_value(&:strip!)
  # binding.pry
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
  @journey = load_journey(params[:journey_id])
  @country = load_country(@journey, params[:country_id])
  @location = load_location(@country, params[:location_id])
  erb :location
end

def load_location(country, id)
  id = id.to_i
  country.locations.find { |l| l.id == id}
end
