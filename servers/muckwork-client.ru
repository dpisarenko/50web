#\ -s thin -E production -p 7004 -P muckwork-client.pid 
require '../routes/muckwork-client.rb'
run MuckworkClientWeb
