#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'yaml'
require 'nokogiri'
require 'fileutils'

# set num_instances
NUM_INSTANCES = ARGV.first || ENV['NUM_INSTANCES'] || '1'

TOKEN_GENERATE_URL="https://discovery.etcd.io/new"

# generate request uri
uri = URI.parse(TOKEN_GENERATE_URL)
new_query_ar = URI.decode_www_form(String(uri.query)) << ['size', NUM_INSTANCES]
uri.query = URI.encode_www_form(new_query_ar)
# or
#uri.query = [uri.query, URI.encode_www_form('size' => 1)].compact.join('&')

# API request
# response = Net::HTTP.get_response(uri)

# Modified 'cl.conf'
File.open('cl.conf') do |conf_file|
  File.readlines(conf_file) do |conf_contents|
    conf_contents.each_line do |line|
      puts line
    end
  end
end

# conf_contents = File.read(conf_file)
# conf_file.close
# confs = YAML.load(conf_contents)
# comments = conf_contents.scan(/^#.*?$/)

# conf_file = File.open('cl.conf')

# conf_contents = File.read(conf_file)
# conf_file.close
# confs = YAML.load(conf_contents)
# comments = conf_contents.scan(/^#.*?$/)

# File.open('cl.conf') do |f|
#   f.each_line do |line|
#     YAML
#   end
# end
# @conf = YAML.load(file)
# file.close

# if !@conf['etcd'].nil?
#   @conf['etcd']['discovery'] = response.body
#   File.open('cl.conf', 'w') do |file|
#     file.puts @conf.to_yaml
#   end
# end

