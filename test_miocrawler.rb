#! /usr/bin/env ruby
# -*- encoding: utf-8 -*-
# test code for miocrawler

require './miocrawler.rb'
require 'pry'
mio = MioParser.new('YOUR_MAIL_ADRESS', 'YOUR_PASSWORD')
mio.scan_data

puts mio.get_user_data
