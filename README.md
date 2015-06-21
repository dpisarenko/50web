# 50web

Websites in Sinatra using a50c (or b50d) gem to access PostgreSQL APIs.

## why?

Before, these would have each been separate repositories, but I'm trying the approach of putting them all into one.  Why?

Because they'll all be running on internal localhost rackups, proxied by nginx.  I start them all in one go.  One workflow that doesn't abandon any site.

## how?

Assume each site has its own domain.  Each has its own nginx config.
Upside: All sites' href links are root-level.  Managing links into subdirectories would have been a mess.
Downside: Separate SSL certificates.  Fair trade.

For each domain that uses client-side JavaScript, nginx proxy /api/xxx to localhost:5000 as needed.
(Internal a50c/b50d gem doesn't need any proxy, since it's accessing API via localhost.)

## auth?

A50C::Auth gets posted email & password, and returns API key and pass values to set in cookies.  No cross-scriping worries, since it's not JavaScript.

# TODO


