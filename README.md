50web
=====

Sinatra websites using a50c gem


# nginx

    server {
    	listen 127.0.0.1:80;
    	server_name 50.web;
    	charset utf-8;
    	default_type  text/html;
    	access_log  /var/log/nginx/50web.access.log  main;
    	error_log  /var/log/nginx/50web.error.log;
    	root /srv/public/50web/public;
    	location = / {
    		rewrite ^ /home.html redirect;
    	}
    	location = /home.html {
    	}
    	# rackup -p9000 in /50apis/
    	# For JavaScript same-domain access, route 50.web/api/* to 127.0.0.1:9000/api/*
    	location ^~ /api/auth/ {
    		proxy_pass http://127.0.0.1:9000;
    		proxy_set_header 'Access-Control-Allow-Origin' 'http://50.web';
    		proxy_set_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE';
    		proxy_set_header 'Access-Control-Allow-Headers' 'X-Requested-With,Accept,Content-Type, Origin';
    		proxy_set_header Host	$host;
    		proxy_set_header X-Real-IP	$remote_addr;
    		proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
    		proxy_redirect http://$host/ http://$host/api/auth/;
    	}
    	location ^~ /api/peep/ {
    		proxy_pass http://127.0.0.1:9000;
    		proxy_set_header Host	$host;
    		proxy_redirect http://$host/ http://$host/api/peep/;
    	}
    	location ^~ /api/sivers-comments/ {
    		proxy_pass http://127.0.0.1:9000;
    		proxy_set_header Host	$host;
    		proxy_redirect http://$host/ http://$host/api/sivers-comments/;
    	}
    	location ^~ /api/muckwork-client/ {
    		proxy_pass http://127.0.0.1:9000;
    		proxy_set_header Host	$host;
    		proxy_redirect http://$host/ http://$host/api/muckwork-client/;
    	}
    	location ^~ /api/musicthoughts/ {
    		proxy_pass http://127.0.0.1:9000;
    		proxy_set_header Host	$host;
    		proxy_redirect http://$host/ http://$host/api/musicthoughts/;
    	}
    	# rackup -p9001 in /50web/
    	# For websites, route 50.web/* to 127.0.0.1:9001/*
    	location ^~ /musicthoughts/ {
    		proxy_pass http://127.0.0.1:9001;
    		proxy_set_header Host	$host;
    		proxy_redirect http://$host/ http://$host/musicthoughts/;
    	}
    	location ~ /(js|css) {
    	}
    	location ~ /images {
    		expires 1y;
    	}
    }


