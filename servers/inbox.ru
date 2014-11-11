#\ -s thin -E production -p 7003 -P inbox.pid 
require '../routes/inbox.rb'
run Inbox
