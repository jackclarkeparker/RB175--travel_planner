require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'

require 'pry'

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

ROOT = File.expand_path('..', __FILE__)

def journeys_path
  File.join(ROOT, 'data/journeys')
end

get "/" do
  @journeys = journey_names
  erb :journeys
end

def journey_names
  Dir.glob(File.join(journeys_path, '*')).map do |file|
    File.basename(file, '.yml')
  end
end

get "/create_journey" do
  erb :create_journey
end

post "/create_journey" do
  @journey_name = params[:journey_name].strip
  @base_country = params[:base_country].strip
  @base_city = params[:base_city].strip
  inputs = { name: @journey_name, country: @base_country, city: @base_city }

  if valid_journey?(inputs)
    File.write(File.join(journeys_path, "#{@journey_name}.yml"), Psych.dump(inputs))
    session["message"] = "Successfully created #{@journey_name}!"
    redirect "/"
  else
    session["message"] = invalid_journey_message(inputs)
    erb :create_journey
  end
end

def valid_journey?(inputs)
  return false if any_empty?(inputs) || name_taken?(inputs[:name])
  true
end

def any_empty?(inputs)
  inputs.any? { |_, input| input.empty? }
end

def name_taken?(input_name)
  journey_names.any? { |journey_name| journey_name == input_name }
end

def invalid_journey_message(inputs)
  case
  when any_empty?(inputs)
    "Please make sure an entry has been supplied in each field."
  when name_taken?(inputs[:name])
    "That name is already in use, please choose another."
  end
end
