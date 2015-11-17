# 50web

Websites in Sinatra accessing PostgreSQL API functions.

## why?

Before, these would have each been separate repositories, but I'm trying the approach of putting them all into one.  Why?

Because they'll all be running on internal localhost rackups, proxied by nginx.  I start them all in one go.  One workflow that doesn't abandon any site.

## how?

Assume each site has its own domain.  Each has its own nginx config.

## auth?

ModAuth gets posted email & password, and returns API key and pass values to set in cookies, HTTP secure only.  No cross-scriping worries, since it's not JavaScript.

# data TODO

* signup - newpass is not null, email formletter with link
* setpass link receiving it: on setpass, makes sure they have apikeys+Data
* signup gives API access
* forgot pass
* how to handle db changes / flags (old/new)
* JavaScript for form field changes
* name, email, city, state, country
* listype
* urls
* now.url
* now-questions if now.url
* JavaScript to go visit site to confirm

