require 'pg'
require 'json'

# PG Pool of connections. Simple as can be. Bypassed if test database.
class PGPool
	@@pool = []
	@@counter = 0
	class << self
		def get(live_or_test='live')
			if 'test' == live_or_test
				return PG::Connection.new(dbname: 'd50b_test', user: 'd50b')
			end
			my_id = @@counter
			@@counter += 1
			@@counter = 0 if 5 == @@counter
			@@pool[my_id] ||= PG::Connection.new(dbname: 'd50b', user: 'd50b')
		end
	end
end

# TODO: curried function instead of initialized class?
# All I really need is the js function.
# Oh, but also the error and message if it fails. Hmm....
class DB2JS
	attr_accessor :error, :message

	def initialize(schema, server='live')
		@schema = schema
		@pg = PGPool.get(server)
	end

	def js(func, params=[])
		res = @pg.exec_params("SELECT mime, js FROM #{@schema + '.' + func}", params)
		j = JSON.parse(res[0]['js'], symbolize_names: true)
		if res[0]['mime'].include? 'problem'
			@error = j[:title]
			@message = j[:detail]
			return false
		else
			@error = @message = nil
			return j
		end
	end

#	def qry(sql, params)
#		@pg.exec_params(sql, params)
#	end
end
