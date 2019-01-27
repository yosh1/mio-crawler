#! /usr/bin/env ruby
# -*- encoding: utf-8 -*-
# IIJmio Crawler for packet usage report

$KCODE = 'UTF8' if RUBY_VERSION < '1.9.0'

require 'kconv'
require 'open-uri'
require 'uri'
require 'logger'

# require 'rubygems'
require 'nokogiri'
require 'mechanize'

class MioParser
  def initialize(user_id, pass, logger = nil)
    @user_id = user_id
    @pass    = pass
    @packet_usage = []
    @agent = Mechanize.new
    if logger.is_a?(Logger)
      @agent.log = logger
    else
      @agent.log = Logger.new(STDOUT)
      @agent.log.level = Logger::INFO
    end
    @logged_in = false
    @user_data = {}
  end

  def get_user_data
    @user_data
  end

  def login
    login_url = 'https://www.iijmio.jp/auth/login.jsp'
    login_form_action = '/j_security_check'
    login_form_id = 'j_username'
    login_form_pass = 'j_password'
    begin
      @agent.get(login_url)
      @agent.log.info 'Logged in : ' + @agent.page.title
      @agent.page.form_with(action: login_form_action) do |form|
        form.field_with(name: login_form_id).value = @user_id
        form.field_with(name: login_form_pass).value = @pass
        form.click_button
      end
    rescue
      @agent.log.error $ERROR_INFO
      return false
    end
    true
  end

  def logout
    logout_url = 'https://www.iijmio.jp/auth/logout.jsp'
    @agent.get(logout_url)
    @agent.log.info 'Logged out url : ' + @agent.page.title
  end

  def logged_in?
    return @logged_in
  end

  def scan_data
    @logged_in = login
    @user_data = scan_user_info
  end

  private
  def scan_user_info
    viewdata_uri = 'https://www.iijmio.jp/service/setup/hdd/viewdata/'
    @agent.get(viewdata_uri)
    @agent.log.info 'Usage page title: ' + @agent.page.title

    @agent.page.form.click_button

    user_data = {}
    user_data = scan_contract(user_data)
    user_data = scan_packet_usage(user_data)

    user_data = scan_coupon_rest(user_data)
    user_data
  end

  def scan_contract(user_data)
    number_xpath = '//table[@class="base2"]/tr[2]'
    number_data = {}
    contents_number = @agent.page.search(number_xpath)
    unless contents_number
      @agent.log.warn 'Parse error at tel-number'
      return user_data
    end
    #binding.pry
    user_data["number"] = /([\d\-]+)/.match(contents_number[0].inner_text)[1]
    user_data
  end

  def scan_packet_usage(user_data)
    usage_array_index = 0
    usage_xpath  = '//table[@class="base2"]/tr'
    contents = @agent.page.search(usage_xpath)
    unless contents
      @agent.log.warn 'Parse error at history data'
      return user_data
    end
    user_data_index = 0
    user_data['usage'] = []
    contents.drop(3).each_with_index do |node, _idx|
      contents_data = node.xpath('./td')
      break unless contents_data
      @agent.log.debug "Usage: #{contents_data}"


      usage_data = {}
      usage_data['date'] = parseDate(contents_data[0].inner_text)
      usage_data['lte_data'] = contents_data[1].inner_text.to_i
      usage_data['restricted_data'] = contents_data[2].inner_text.to_i

      user_data['usage'].push  usage_data
    end

    user_data
  end

  def scan_coupon_rest(user_data)
    coupon_uri = 'https://www.iijmio.jp/service/setup/hdd/couponstatus/'

    coupon_total_xpath = '//table[@class="base2"]/tr[2]/td[2]'
    coupon_this_month_xpath = '//table[@class="base2"]/tr[3]/td[2]'
    coupon_prev_month_xpath = '//table[@class="base2"]/tr[4]/td[2]'

    @agent.get(coupon_uri)
    @agent.log.info 'Coupon page title: ' + @agent.page.title

    total = getNumericData_xpath(@agent.page, coupon_total_xpath)
    this_month = getNumericData_xpath(@agent.page, coupon_this_month_xpath)
    prev_month = getNumericData_xpath(@agent.page, coupon_prev_month_xpath)

    @agent.log.debug "Coupon data: total=#{total}, this_month=#{this_month}, prev_month=#{prev_month}"

    user_data["coupon"] = [total, this_month, prev_month]
    user_data
  end

  def getNumericData_xpath(page, xpath)
    contents = page.at(xpath)
    return contents ? contents.inner_text.to_i : 0
  end

  def parseDate(str)
    if /[\s　]*(\d+)年[\s　]*(\d+)月[\s　]*(\d+)日/ =~ str
        return Time.local(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3))
    else
        return nil
    end
  end

end
