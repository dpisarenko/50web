#\ -s thin -E production -p 7007 -P muck-worker.pid 
require '../routes/muck-worker.rb'
run MuckWorkerWeb
