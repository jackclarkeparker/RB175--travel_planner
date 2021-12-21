require_relative 'journey_classes'

trip = Journey.new('visit_vietnam')
p trip
trip.add_country('New Zealand')

nz = trip.countries["New Zealand"]
p nz

nz.add_location('Wellington')
wgtn = nz.locations["Wellington"]
p wgtn

wgtn.set_arrival_date(Date.today)
