#\ -s thin -E production -p 7000 -P auth.pid 
require '../routes/auth.rb'
run AuthWeb
