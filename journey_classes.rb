require 'date'
require 'redcarpet'

module Temporable
  attr_reader :temporable_details

  def set_arrival_date(d)
    temporable_details[:arrival_date] = d
  end

  def set_departure_date(d)
    temporable_details[:departure_date] = d
  end

  def set_entry_date(d)
    temporable_details[:entry_date] = d
  end

  def set_exit_date(d)
    temporable_details[:exit_date] = d
  end

  def set_arrival_time(time)
    temporable_details[:arrival_time] = time
  end

  def set_departure_time(time)
    temporable_details[:departure_time] = time
  end

  def set_starting_time(t)
    temporable_details[:starting_time] = t
  end

  def set_ending_time(t)
    temporable_details[:ending_time] = t
  end

  def set_check_in_time(time)
    temporable_details[:check_in_time] = time
  end

  def set_check_out_time(time)
    temporable_details[:check_out_time] = time
  end

  private

  attr_writer :temporable_details
end

module Detailable
  attr_reader :details, :pros, :cons

  def markdown_to_html(content)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end

  def set_details(d)
    self.details = d
  end

  def set_pros(p)
    self.pros = p
  end

  def set_cons(c)
    self.cons = c
  end

  def rendered_details
    markdown_to_html(@details)
  end

  def rendered_pros
    markdown_to_html(@pros)
  end

  def rendered_cons
    markdown_to_html(@cons)
  end

  private

  attr_writer :details, :pros, :cons
end

module Addressable
  attr_reader :addressable_details

  def set_arrival_address(address)
    addressable_details[:arrival_address] = address
  end

  def set_departure_address(address)
    addressable_details[:departure_address] = address
  end

  def set_address(a)
    addressable_details[:address] = a
  end

  private

  attr_writer :addressable_details
end

module Costable
  attr_reader :cost, :rating

  def set_cost(c)
    self.cost = c
  end

  def set_rating(r)
    self.rating = r
  end

  private

  attr_writer :cost, :rating
end

module PathToFile
  def add_path_to_file(path)
    self.path_to_file = path
  end
end

class Journey
  include Detailable

  attr_reader :name, :camel_case_name, :id, :countries

  def initialize(name)
    @name = name
    @camel_case_name = self.class.camel_casify(name)
    @id = new_journey_id
    @countries = []
    @details = nil
    @pros = nil
    @cons = nil
  end

  def add_country(country)
    c =  Country.new(country, new_country_id)
    countries << c
    c
  end

  def self.camel_casify(name)
    name.downcase.gsub(' ', '_')
  end

  private

  def new_journey_id
    id = 1
    loop do
      return id if load_journeys.none? { |j| j.id == id }
      id += 1
    end
  end

  def new_country_id
    id = 1
    loop do
      return id if countries.none? { |c| c.id == id }
      id += 1
    end
  end
end

class Country
  include Detailable

  attr_reader :name, :id, :locations, :visa

  def initialize(name, id)
    @name = name
    @id = id
    @locations = []
    @visa = nil
    @length_of_stay = nil
  end

  def add_location(name)
    l = Location.new(name, new_location_id)
    locations << l
    l
  end

  def length_of_stay
    (locations.last.departure_date - locations.first.arrival_date).to_i
  end

  def set_visa(needed:)
    self.visa = needed ? Visa.new : 'not needed'
  end

  private

  def new_location_id
    id = 1
    loop do
      return id if locations.none? { |l| l.id == id }
      id += 1
    end
  end

  attr_writer :visa
end

class Location
  include Temporable, Detailable

  attr_reader :name, :id, :departure_ticket # Could store these as a range
  attr_reader :activities, :accomodations, :photos

  def initialize(name, id)
    @name = name
    @id = id
    @temporable_details = { arrival_date: nil, departure_date: nil }
    @departure_ticket = nil
    @accomodations = []
    @activities = []
    @photos = []
    @details = nil
    @pros = nil
    @cons = nil
  end

  def add_accomodation(name) # Use hash with acc key instead?
    a = Accomodation.new(name, new_accomodation_id)
    accomodations << a
    a
  end

  def add_activity(name) # Use hash with acc key instead?
    a = Activity.new(name, new_activity_id)
    activities << a
    a
  end

  def set_departure_ticket
    self.departure_ticket = DepartureTicket.new
  end

  def add_photo(path)
    photos << path
  end

  private

  def new_accomodation_id
    id = 1
    loop do
      return id if accomodations.none? { |a| a.id == id }
      id += 1
    end
  end

  def new_activity_id
    id = 1
    loop do
      return id if activities.none? { |a| a.id == id }
      id += 1
    end
  end

  attr_writer :departure_ticket
end

class Activity
  include Temporable, Addressable, Costable, Detailable

  attr_reader :name, :id, :to_bring
  attr_reader :addressable_details

  def initialize(name, id)
    @name = name
    @id = id
    @cost = nil
    @rating = nil
    @pros = nil
    @cons = nil
    @temporable_details = { starting_time: nil, ending_time: nil }
    @addressable_details = { starting_address: nil, ending_address: nil }
    @to_bring = []
  end

  def set_to_bring(items)
    to_bring << items
  end
end

class Accomodation # Too ambiguous? Sometimes we'll stay in a temporary accomodation, othertimes we'll rent an apartment
  include Temporable, Addressable, Costable, Detailable

  attr_reader :name, :id, :address
  attr_reader :booking_service

  def initialize(name, id)
    @name = name
    @id = id
    @cost = nil
    @rating = nil
    @details = nil
    @pros = nil
    @cons = nil
    @address = nil
    @temporable_details = { 
      arrival_date: nil,
      departure_date: nil,
      check_in_time: nil,
      check_out_time: nil
    }
    @booking_service = nil
  end

  def set_booking_service(service)
    self.booking_service = service
  end

  private

  attr_writer :name, :address, :booking_service
end

class DepartureTicket
  include Temporable, Addressable, PathToFile, Detailable, Costable

  attr_reader :transport_mode, :transport_provider
  attr_reader :ticket_number, :path_to_file

  def initialize
    @transport_mode = nil
    @temporable_details = { departure_time: nil, arrival_time: nil }
    @addressable_details = { departure_address: nil, arrival_address: nil }
    @transport_provider = nil
    @ticket_number = nil
    @path_to_file = nil
    @cost = nil
    @rating = nil
    @details = nil
    @pros = nil
    @cons = nil
  end
  
  def set_transport_mode(mode)
    self.transport_mode = mode
  end

  def set_ticket_number(number)
    self.ticket_number = number
  end

  def set_transport_provider(provider)
    self.transport_provider = provider
  end

  def trip_duration
    arrival_time - departure_time
  end

  private

  attr_writer :transport_mode, :transport_provider
  attr_writer :ticket_number, :path_to_file
end

class Visa
  include Temporable, PathToFile, Costable, Detailable

  attr_reader :type, :number, :path_to_file

  def initialize
    @type = nil
    @number = nil
    @temporable_details = { entry_date: nil, exit_date: nil }
    @information = nil
    @path_to_file = nil
  end

  def set_visa_type(t)
    self.type = t
  end

  def set_visa_number(n)
    self.number = n
  end

  def set_information(i)
    self.information = i
  end

  private

  attr_writer :type, :number, :path_to_file
end
