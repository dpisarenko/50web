# Test https://data.sivers.org/ from user perspective.
# NOTE: Tests are long sessions testing many things because Selenium's sessions
# take a long time to setup and teardown. So instead use one scenario per test.

# reset database before & after each test. also creates DB constant for below.
DBDIR = '/srv/public/db-api/'
SCHEMA = File.read("#{DBDIR}peeps/schema.sql")
FIXTURES = File.read("#{DBDIR}peeps/fixtures.sql")
require "#{DBDIR}test_tools.rb"
require 'selenium-webdriver'
require 'minitest/autorun'

class TestSiversData < Minitest::Test

	def setup
		super # see DBDIR/test_tools.rb
		@host = 'https://sivdata.dev'
		@browser ||= Selenium::WebDriver.for :firefox
	end

	def teardown
		@browser.close
	end

	# FIRST-TIME USER: CREATE-AND-AUTH
	def test_first_timer
		# not logged in, sends back to login page
		@browser.get(@host)
		assert_equal @host + '/login', @browser.current_url

		# attempt log in with bad email
		@browser.get(@host + '/login')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca'
		el = @browser.find_element(:id, 'password')
		el.send_keys 'booop'
		el.submit
		assert_equal(@host + '/sorry?for=bademail', @browser.current_url)

		# attempt log in with unknown email
		@browser.get(@host + '/login')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@gmail.com'
		el = @browser.find_element(:id, 'password')
		el.send_keys 'booop'
		el.submit
		assert_equal(@host + '/sorry?for=badlogin', @browser.current_url)

		# attempt log in with bad password
		@browser.get(@host + '/login')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@salt.com'
		el = @browser.find_element(:id, 'password')
		el.send_keys 'wrong-password'
		el.submit
		assert_equal(@host + '/sorry?for=badlogin', @browser.current_url)

		# /getpass submit bademail
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@salt'
		el.submit
		assert_equal(@host + '/sorry?for=bademail', @browser.current_url)

		# /getpass submit unknown email
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@gmail.com'
		el.submit
		assert_equal(@host + '/sorry?for=unknown', @browser.current_url)

		# /getpass submit correct & check email
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@salt.com'
		el.submit
		assert_equal(@host + '/thanks?for=getpass', @browser.current_url)
		res = DB.exec("SELECT body FROM peeps.emails WHERE id=11")
		assert_equal 1, res.ntuples
		m = %r{(/newpass/3/[A-Za-z0-9]{8})\s}.match res[0]['body']
		my_newpass_link = m[1]

		# follow link in email & try too-short password
		@browser.get(@host + my_newpass_link)
		el = @browser.find_element(:id, 'setpass')
		el.send_keys 'bad'
		el.submit
		assert_equal(@host + my_newpass_link, @browser.current_url)

		# now make good password
		password = 'I!Want!It!Now!'
		el = @browser.find_element(:id, 'setpass')
		el.send_keys password
		el.submit
		assert_equal(@host + '/', @browser.current_url)

		# ok cookie should be set
		assert_equal 1, @browser.manage.all_cookies.size
		ok = @browser.manage.all_cookies.find do |cookie|
			cookie[:name] == 'ok'
		end
		assert_match /[a-zA-Z0-9]{32}%3A[a-zA-Z0-9]{32}/, ok[:value]

		# if logged in, that newpass link goes home
		@browser.get(@host + my_newpass_link)
		assert_equal(@host + '/', @browser.current_url)

		# deleting "ok" cookie logs out
		@browser.manage.delete_cookie 'ok'
		@browser.get(@host)
		assert_equal @host + '/login', @browser.current_url

		# log in with new password
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@salt.com'
		el = @browser.find_element(:id, 'password')
		el.send_keys password
		el.submit
		assert_equal(@host + '/', @browser.current_url)

		# logout erases cookies & sends to login page
		@browser.get(@host + '/logout')
		assert_equal @host + '/login', @browser.current_url
		@browser.get(@host)
		assert_equal @host + '/login', @browser.current_url
		assert_equal 0, @browser.manage.all_cookies.size

		# now that newpass link doesn't work
		@browser.get(@host + my_newpass_link)
		assert_equal(@host + '/sorry?for=badid', @browser.current_url)
	end

end
