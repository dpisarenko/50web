#\ -s thin -E production -p 7008 -P muck-manager.pid 
require '../routes/muck-manager.rb'
run MuckManagerWeb
