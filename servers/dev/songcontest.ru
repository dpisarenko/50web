#\ -s thin -E production -p 7005 -P songcontest.pid 
require '../../routes/songcontest.rb'
run SongContest
