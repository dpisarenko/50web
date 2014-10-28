require 'sinatra/base'
require 'rabl'

require 'd50b/test'

require './routes/auth.rb'
map('/api/auth') { run Auth }

require './routes/peep.rb'
map('/api/peep') { run Peep }

require 'd50b/sivers'
require './routes/sivers-comments.rb'
map('/api/sivers-comments') { run SiversComments }

require 'd50b/musicthoughts'
require './routes/musicthoughts.rb'
map('/api/musicthoughts') { run MusicThoughtsPublic }

require 'd50b/muckwork'
require './routes/muckwork-client.rb'
map('/api/muckwork-client') { run MuckworkClient }

