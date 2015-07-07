# 50web

Websites in Sinatra using b50d gem to access PostgreSQL APIs.

MusicThoughts is now bypassing b50d and calling the PostgreSQL API functions directly.  If they're really going to stay on the same server, this can't hurt, but if they might go over HTTP + REST API then it should probably go back to a library wrapper, right?  Either way, point is: avoiding the library helps me ensure there's not more necessary stuff going on in the library, that the PostgreSQL API functions are really handling everything possible.  This will make it easier to switch to another language when needed, with minimal rewriting.

## why?

Before, these would have each been separate repositories, but I'm trying the approach of putting them all into one.  Why?

Because they'll all be running on internal localhost rackups, proxied by nginx.  I start them all in one go.  One workflow that doesn't abandon any site.

## how?

Assume each site has its own domain.  Each has its own nginx config.

For each domain that uses client-side JavaScript, nginx proxy /api/xxx to localhost:5000 as needed.
(Internal a50c/b50d gem doesn't need any proxy, since it's accessing API via localhost.)

## auth?

A50C::Auth gets posted email & password, and returns API key and pass values to set in cookies.  No cross-scriping worries, since it's not JavaScript.

