require 'date'

module Temporable
  def set_arrival_date(d)
    temporable_details[:arrival_date] = d
  end

  def set_departure_date(d)
    temporable_details[:departure_date] = d
  end

  def set_departure_time(time)
    temporable_details[:departure_time] = time
  end

  def set_arrival_time(time)
    temporable_details[:arrival_time] = time
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
end

module Detailable
  def set_details(d)
    self.details = d
  end

  def set_pros(p)
    self.pros = p
  end

  def set_cons(c)
    self.cons = c
  end
end

module Addressable
  def set_arrival_address(address)
    addressable_details[:arrival_address] = address
  end

  def set_departure_address(address)
    addressable_details[:departure_address] = address
  end

  def set_address(a)
    addressable_details[:address] = a
  end
end

module Costable
  def set_cost(c)
    self.cost = c
  end
end

module PathToFile
  def add_path_to_file(path)
    self.path_to_file = path
  end
end

class Journey
  include Detailable

  attr_reader :name, :camel_case_name, :countries, :details, :pros, :cons

  def initialize(name)
    @name = name
    @camel_case_name = self.class.camel_casify(name)
    @countries = {}
  end

  def add_country(country)
    countries[country] = Country.new(country)
  end

  def self.camel_casify(name)
    name.downcase.gsub(' ', '_')
  end

  private

  attr_writer :details, :pros, :cons
end

class Country
  include Detailable

  attr_reader :name, :locations, :visa, :details, :pros, :cons

  def initialize(name)
    @name = name
    @locations = {}
    @visa = nil
    @length_of_stay = nil
  end

  def add_location(name)
    locations[name] = Location.new(name)
  end

  def length_of_stay
    (locations.last.departure_date - locations.first.arrival_date).to_i
  end

  def set_visa(needed:)
    self.visa = needed ? Visa.new : 'not needed'
  end

  private

  attr_writer :visa, :details, :pros, :cons
end

class Location
  include Temporable, Detailable

  attr_reader :temporable_details, :departure_ticket # Could store these as a range
  attr_reader :activities, :accomodation, :photos
  attr_reader :details, :pros, :cons

  def initialize(name)
    @name = name
    @temporable_details = { arrival_date: nil, departure_date: nil }
    @departure_ticket = nil
    @accomodation = []
    @activites = []
    @photos = []
    @details = nil
    @pros = nil
    @cons = nil
  end

  def add_accomodation(acc) # Use hash with acc key instead?
    accomodation << Accomodation.new(acc)
  end

  def add_activity(a) # Use hash with acc key instead?
    activities << Activity.new(act)
  end

  def set_departure_ticket
    self.departure_ticket = DepartureTicket.new
  end

  def add_photo(path)
    photos << path
  end

  private

  attr_writer :details, :pros, :cons, :departure_ticket
end

class Activity
  include Temporable, Addressable, Costable, Detailable

  attr_reader :cost, :details, :pros, :cons
  attr_reader :temporable_details, :addressable_details
  attr_reader :to_bring

  def initialize(name)
    @name = name
    @cost = nil
    @pros = nil
    @cons = nil
    @temporable_details = { starting_time: nil, ending_time: nil }
    @addressable_details = { starting_address: nil, ending_address: nil }
    @to_bring = []
  end

  def set_pros(p)
    self.pros = p
  end

  def set_cons(c)
    self.cons = c
  end

  def add_item_to_bring(item)
    to_bring << item
  end

  private 

  attr_writer :cost, :details, :pros, :cons
end

class Accomodation # Too ambiguous? Sometimes we'll stay in a temporary accomodation, othertimes we'll rent an apartment
  include Temporable, Addressable, Costable, Detailable

  attr_reader :name, :cost, :details, :pros, :cons
  attr_reader :address, :temporable_details, :booking_service

  def initialize(name)
    @name = name
    @cost = nil
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

  attr_writer :name, :cost, :details, :pros, :cons
  attr_writer :address, :booking_service
end

class DepartureTicket
  include Temporable, Addressable, PathToFile, Detailable

  attr_reader :transport_mode, :departure_time, :arrival_time
  attr_reader :departure_address, :arrival_address, :transport_provider
  attr_reader :ticket_number, :path_to_file
  attr_reader :cost, :details, :pros, :cons

  def initialize
    @transport_mode = nil
    @temporable_details = { departure_time: nil, arrival_time: nil }
    @addressable_details = { departure_address: nil, arrival_address: nil }
    @transport_provider = nil
    @ticket_number = nil
    @path_to_file = nil
    @cost = nil
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

  attr_writer :transport_mode, :departure_time, :arrival_time
  attr_writer :departure_address, :arrival_address, :transport_provider
  attr_writer :ticket_number, :path_to_file
  attr_writer :cost, :details, :pros, :cons
end

class Visa
  include Temporable, PathToFile, Costable, Detailable

  attr_reader :type, :number, :entry_date, :exit_date, :path_to_file
  attr_reader :cost, :details, :pros, :cons

  def initialize
    @type = nil
    @number = nil
    @entry_date = nil
    @exit_date = nil
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

  attr_writer :type, :number, :entry_date, :exit_date, :path_to_file
  attr_writer :cost, :details, :pros, :cons
end
