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
  def countries_visiting(journey)
    journey[:starting_country] + journey[:locations]
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
    journey = Journey.new(@journey_name)
    journey_path = File.join(data_path, "#{journey.camel_case_name}.yml")
    File.write(journey_path, Psych.dump(journey))

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

get "/journeys/:journey" do
  if nonexistent_journey?(params[:journey])
    session[:message] = "That journey doesn't exist"
    redirect "/"
  else
    @journey = load_journey(params[:journey])
    erb :journey
  end
end

def load_journey(journey)
  YAML.load_file(File.join(data_path, "#{journey}.yml"))
end

def nonexistent_journey?(journey)
  !name_in_use?(journey)
end

get "/journeys/:journey/add_country" do
  @journey = load_journey(params[:journey])
  erb :add_country
end

post "/journeys/:journey/add_country" do
  @journey = load_journey(params[:journey])

  params.each { |_, v| v.strip! }
  @country = params[:country]
  @city = params[:city]
  @arrival_date = params[:arrival_date]

  if invalid_new_country?(params)
    status 422
    session[:message] = message_for_invalid_new_country(params)
    erb :add_country
  else
    add_initial_country(@journey, @country, @city, @arrival_date)
    save_journey(@journey)

    redirect "/journeys/#{@journey.name}"
  end
end

def add_initial_country(journey, country, location, arrival_date)
  c = journey.add_country(country)
  l = c.add_location(location)
  l.set_arrival_date(arrival_date)
end

def save_journey(journey)
  File.write(File.join(data_path, "#{journey.name}.yml"), Psych.dump(journey))
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
