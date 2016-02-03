require 'pg'
Object.const_set(:DB, PG::Connection.new(:dbname => 'd50b', :user => 'd50b', :password => 'd50b'))
require '../../routes/lat.rb'
run Lat
