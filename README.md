# 50web

Websites in Sinatra using a50c gem to access 50apis API.  I think this will include:

* musicthoughts.com
* musicthoughts.net (admin)
* sivers-comments
* inbox
* muckwork.com (client)
* muckwork.net (manager)
* muckwork.org (worker)
* … etc. for songtest, cyrano, and future ideas

## why?

Before, these would have each been separate repositories, but I'm trying the approach of putting them all into one.  Why?

Because they'll all be running on internal localhost rackups, proxied by nginx.  I'd like to start them all in one go, like I do with 50apis.  Use Gulp and bundler once to keep gems and assets up to date.  One workflow that doesn't abandon any site.  (Yeah these are pretty weak reasons.  So maybe it's “Why not?”)

## how?

Assume each site has its own domain.  Each has its own nginx config.
Upside: All sites' href links are root-level.  Managing links into subdirectories would have been a mess.
Downside: Separate SSL certificates.

For each domain that uses client-side JavaScript, nginx proxy /api/xxx to localhost:9000 as needed.
(Internal a50c gem doesn't need any proxy, since it's accessing API via localhost.)

TODO: get each Sinatra app on its own internal port number, so they don't need to be mounted at subdirectories.

## auth?

I liked the 50apps auth method.  Rename them by domain?

Home: 50.io is the site that requires auth to get into, but once in, is just a menu of which other sites you're authed to use.

## nginx

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


