require 'sinatra/base'
#require 'd50b/test'

require './routes/musicthoughts.rb'
map('/musicthoughts') { run MusicThoughtsWeb }

