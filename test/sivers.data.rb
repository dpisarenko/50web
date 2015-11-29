require 'selenium-webdriver'
require 'minitest/autorun'

class TestSiversData < Minitest::Test

	def setup
		@host = 'https://sivdata.dev'
		@browser = Selenium::WebDriver.for :firefox
	end

	def teardown
		@browser.quit
	end

	def login(email)
		@browser.get @host + '/login'
		el = @browser.find_element(:id, 'email')
		el.send_keys email
		el = @browser.find_element(:id, 'password')
		el.send_keys email.split('@')[0]
		el.submit
	end

	def test_init
		@browser.get @host
		assert_equal @host + '/login', @browser.current_url
	end

	def test_login
		login 'derek@sivers.org'
		assert_equal 'your data | data.sivers.org', @browser.title
	end

end
