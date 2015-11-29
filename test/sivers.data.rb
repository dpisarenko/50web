require 'selenium-webdriver'
require 'minitest/autorun'
require 'b50d/getdb'

class TestSiversData < Minitest::Test

	def setup
		@host = 'https://sivdata.dev'
		@browser ||= Selenium::WebDriver.for :firefox
	end

	def teardown
		@browser.close
	end

	def login(email)
		@browser.get(@host + '/login')
		el = @browser.find_element(:id, 'email')
		el.send_keys email
		el = @browser.find_element(:id, 'password')
		el.send_keys email.split('@')[0]
		el.submit
	end

	def test_init
		@browser.get(@host)
		assert_equal @host + '/login', @browser.current_url
	end

	def test_login
		login 'derek@sivers.org'
		assert_equal 'your data | data.sivers.org', @browser.title
	end

	def test_getpass_authed
		login 'derek@sivers.org'
		@browser.get(@host + '/getpass')  # sends home:
		assert_equal @host + '/', @browser.current_url
	end

	def test_getpass_bad
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'invalid@wrong'
		el.submit
		assert_equal(@host + '/sorry?for=bademail', @browser.current_url)
	end

	def test_getpass_unknown
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'valid@not.found'
		el.submit
		assert_equal(@host + '/sorry?for=unknown', @browser.current_url)
	end

	def test_getpass_submit
		db = getdb('peeps', 'test')
		@browser.get(@host + '/getpass')
		el = @browser.find_element(:id, 'email')
		el.send_keys 'veruca@salt.com'
		el.submit
	end

end
