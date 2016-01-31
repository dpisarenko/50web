#\ -s thin -E production -p 7006 -P muck-client.pid 
require '../../routes/muck-client.rb'
run MuckClientWeb
