# 50web

Websites in Sinatra using a50c gem to access 50apis API.  I think this will include:

* musicthoughts.com
* sivers-comments
* inbox
* musicthoughts.net (admin)
* muckwork.com (client)
* muckwork.biz (manager)
* muckwork.net (worker)
* … etc. for songtest, cyrano, and future ideas

## why?

Before, these would have each been separate repositories, but I'm trying the approach of putting them all into one.  Why?

Because they'll all be running on internal localhost rackups, proxied by nginx.  I start them all in one go.  One workflow that doesn't abandon any site.

## how?

Assume each site has its own domain.  Each has its own nginx config.
Upside: All sites' href links are root-level.  Managing links into subdirectories would have been a mess.
Downside: Separate SSL certificates.  Fair trade.

For each domain that uses client-side JavaScript, nginx proxy /api/xxx to localhost:5000 as needed.
(Internal a50c gem doesn't need any proxy, since it's accessing API via localhost.)

## auth?

A50C::Auth gets posted email & password, and returns API key and pass values to set in cookies.  No cross-scriping worries, since it's not JavaScript.

# TODO:

INBOX: /countries /stats /merge

