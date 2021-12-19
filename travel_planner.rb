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

def data_path
  if ENV["RACK_ENV"] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

get "/" do
  @journeys = journey_names
  erb :journeys
end

def journey_names
  Dir.glob(File.join(data_path, '*')).map do |file|
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

  if invalid_journey?(inputs)
    session["message"] = invalid_journey_message(inputs)
    erb :create_journey
  else
    File.write(File.join(data_path, "#{@journey_name}.yml"), Psych.dump(inputs))
    session["message"] = "Successfully created #{@journey_name}!"
    redirect "/"
  end
end

def invalid_journey?(inputs)
  invalid_chars?(inputs[:name]) ||
  name_taken?(inputs[:name]) ||
  any_empty?(inputs)
end

def invalid_chars?(input_name)
  !input_name.match?(/\A[a-z0-9_-]*\z/i)
end

def name_taken?(input_name)
  journey_names.any? { |journey_name| journey_name == input_name }
end

def any_empty?(inputs)
  inputs.any? { |_, input| input.empty? }
end

def invalid_journey_message(inputs)
  case
  when invalid_chars?(inputs[:name])
    "Journey name must be constructed with alphanumerics, hyphens," \
    " and underscores only."
  when name_taken?(inputs[:name])
    "That name is already in use, please choose another."
  when any_empty?(inputs)
    "Please make sure an entry has been supplied in each field."
  end
end
