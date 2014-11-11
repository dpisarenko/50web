# 50web

Websites in Sinatra using a50c gem to access 50apis API.  I think this will include:

* 50.io
* musicthoughts.com
* sivers-comments
* inbox
* musicthoughts.net (admin)
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

For each domain that uses client-side JavaScript, nginx proxy /api/xxx to localhost:5000 as needed.
(Internal a50c gem doesn't need any proxy, since it's accessing API via localhost.)

TODO: get each Sinatra app on its own internal port number, so they don't need to be mounted at subdirectories.

## auth?

I liked the 50apps auth method.  Rename them by domain?

Home: 50.io is the site that requires auth to get into, but once in, is just a menu of which other sites you're authed to use.

## nginx

```
server {
	listen 127.0.0.1:80;
	server_name 50.dev;
	charset utf-8;
	default_type  text/html;
	access_log  /var/log/nginx/50.access.log  main;
	error_log  /var/log/nginx/50.error.log;
	root /srv/public/50web/public;
	location ~ /(css|images|js) {
		expires 1d;
	}
	location / {
		proxy_pass http://127.0.0.1:7000;
		proxy_redirect http://$host/ http://50.dev/;
		proxy_buffering on;
		proxy_buffers 12 12k;
		proxy_headers_hash_max_size 1024;
		proxy_headers_hash_bucket_size 128;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $remote_addr;
		proxy_set_header Host $host;
	}
}


server {
	listen 127.0.0.1:80;
	server_name musicthoughts.dev;
	charset utf-8;
	default_type  text/html;
	access_log  /var/log/nginx/musicthoughts.access.log  main;
	error_log  /var/log/nginx/musicthoughts.error.log;
	root /srv/public/50web/public;
	location ~ /(css|images|js) {
		expires 1d;
	}
	location / {
		proxy_pass http://127.0.0.1:7001;
		proxy_redirect http://$host/ http://musicthoughts.dev/;
		proxy_buffering on;
		proxy_buffers 12 12k;
		proxy_headers_hash_max_size 1024;
		proxy_headers_hash_bucket_size 128;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $remote_addr;
		proxy_set_header Host $host;
	}
}


server {
	listen 127.0.0.1:80;
	server_name comments.dev;
	charset utf-8;
	default_type  text/html;
	access_log  /var/log/nginx/comments.access.log  main;
	error_log  /var/log/nginx/comments.error.log;
	root /srv/public/50web/public;
	location ~ /(css|images|js) {
		expires 1d;
	}
	location / {
		proxy_pass http://127.0.0.1:7002;
		proxy_redirect http://$host/ http://comments.dev/;
		proxy_buffering on;
		proxy_buffers 12 12k;
		proxy_headers_hash_max_size 1024;
		proxy_headers_hash_bucket_size 128;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $remote_addr;
		proxy_set_header Host $host;
	}
}

server {
	listen 127.0.0.1:80;
	server_name inbox.dev;
	charset utf-8;
	default_type  text/html;
	access_log  /var/log/nginx/inbox.access.log  main;
	error_log  /var/log/nginx/inbox.error.log;
	root /srv/public/50web/public;
	location ~ /(css|images|js) {
		expires 1d;
	}
	location / {
		proxy_pass http://127.0.0.1:7003;
		proxy_redirect http://$host/ http://inbox.dev/;
		proxy_buffering on;
		proxy_buffers 12 12k;
		proxy_headers_hash_max_size 1024;
		proxy_headers_hash_bucket_size 128;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $remote_addr;
		proxy_set_header Host $host;
	}
}
```
