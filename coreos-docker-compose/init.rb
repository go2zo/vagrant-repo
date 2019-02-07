#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'logger'
require 'open3'

logger = Logger.new(STDOUT)

# set num_instances
$num_instances = 1
if ENV["NUM_INSTANCES"].to_i > 0 && ENV["NUM_INSTANCES"]
  $num_instances = ENV["NUM_INSTANCES"].to_i
end

# load num_instances in config.rb
CONFIG = File.join(File.dirname(__FILE__), "config.rb")
CL_CONFIG = File.join(File.dirname(__FILE__), "cl.conf")
CONFIG_IGN = File.join(File.dirname(__FILE__), "config.ign")

if File.exist?(CONFIG)
  require CONFIG
end

logger.info("instances size: #{$num_instances}")

# 1. generate etcd token
# token generation API
TOKEN_GENERATE_URL="https://discovery.etcd.io/new"

# # 1-1. instances size를 parameter로 입력
uri = URI.parse(TOKEN_GENERATE_URL)
new_query_ar = URI.decode_www_form(String(uri.query)) << ['size', $num_instances]
uri.query = URI.encode_www_form(new_query_ar)
# or
#uri.query = [uri.query, URI.encode_www_form('size' => 1)].compact.join('&')

# 1-2. rest API를 호출해 response 받음
logger.info("Request URI: #{uri}")
response = Net::HTTP.get_response(uri)
logger.info("Response Body: #{response.body}")

# 2. 'cl.conf' 파일이 있는 경우 cl.conf --> config.ign transform
if File.exist?(CL_CONFIG)
  # 2-1. etcd token을 새로 생성한 토큰으로 replace
  File.open(CL_CONFIG, 'r+') do |conf_file|
    isEtcd = false
    newLines = Array.new

    # one line 씩 읽으며 키로 검색하여 해당하는 value를 replace
    File.readlines(conf_file).each do |line|
      isEtcd = line.strip.start_with?("etcd:")

      if isEtcd && line.strip.start_with?("discovery:")
        line = line.gsub(/(\").*(\"$)/, "\\1#{response.body}\\2")
      end

      #newLines.push(line)
      newLines << line
    end
    
    conf_file.rewind
    # puts는 write와 다르게 new line을 자동 입력
    conf_file.puts(newLines)
    logger.info("'cl.conf' is successfully updated.")
  end

  # 시스템에 Config Transpiler(ct)가 있는지 확인
  ct_cmd = 'ct'
  platform = 'vagrant-virtualbox'
  pretty_print = false
  stdout, stderr, status = Open3.capture3("which #{ct_cmd}")
  
  # 2-2. Config Transpiler(ct) utility를 통해 config.ign 파일 생성
  if status.success?
    # ERROR: ct full path를 사용하는 경우 '지정된 경로를 찾을 수 없습니다.'
    #cmd = "#{CT_PATH.strip} --platform=#{platform} #{pretty_print ? '--pretty ' : ''}< #{CL_CONFIG} > #{CONFIG_IGN}"
    cmd = "#{ct_cmd} --platform=#{platform} #{'--pretty ' if pretty_print}< #{CL_CONFIG} > #{CONFIG_IGN}"
    logger.info("Executed shell script: #{cmd}")

    Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
      until stderr.eof? do
        logger.error(stderr.gets)
      end
    end
  end
end

# 3. vagrant 실행
Open3.popen3("vagrant up --provision") do |stdin, stdout, stderr, thread|
  io = thread.value.success

end