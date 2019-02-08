#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'logger'
require 'open3'

$logger = Logger.new(STDOUT)

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

$logger.info("instances size: #{$num_instances}")

def execute_cmd(cmd)
  $logger.info("Executed shell script: #{cmd}")

  Open3.popen2e(cmd) do |stdin, stdout_and_stderr, thread|
    until stdout_and_stderr.eof?
      $logger.info(stdout_and_stderr.gets.strip)
    end
  end
end

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
$logger.info("Request URI: #{uri}")
response = Net::HTTP.get_response(uri)
$logger.info("Response Body: #{response.body}")

# 2. 'cl.conf' 파일이 있는 경우 cl.conf --> config.ign transform
if File.exist?(CL_CONFIG)
  # 2-1. etcd token을 새로 생성한 토큰으로 replace
  File.open(CL_CONFIG, mode: 'r+', crlf_newline: false) do |conf_file|
    newLines = Array.new

    # one line 씩 읽으며 키로 검색하여 해당하는 value를 replace
    ws_size = -1
    is_etcd = false
    is_etcd_discovery = false

    File.readlines(conf_file).each do |line|
      match = line.match(/^(\s*)(\w+):/)
      unless match.nil?
        if ws_size < 0 || match[1].length <= ws_size
          ws_size = match[1].length
          is_etcd = match[2].eql?("etcd")
        end
        is_etcd_discovery = is_etcd && match[2].eql?("discovery")
      end

      line = line.gsub(/(\").*(\"$)/, "\\1#{response.body}\\2") if is_etcd_discovery
      newLines << line
    end
    
    conf_file.rewind
    # puts는 write와 다르게 new line을 자동 입력
    conf_file.puts(newLines)
    $logger.info("'cl.conf' is successfully updated.")
  end

  # 시스템에 Config Transpiler(ct)가 있는지 확인
  ct_cmd = 'ct'
  platform = 'vagrant-virtualbox'
  pretty_print = false
  stdout_and_stderr_str, status = Open3.capture2e("which #{ct_cmd}")
  
  # 2-2. Config Transpiler(ct) utility를 통해 config.ign 파일 생성
  if status.success?
    # ERROR: ct full path를 사용하는 경우 '지정된 경로를 찾을 수 없습니다.'
    #cmd = "#{CT_PATH.strip} --platform=#{platform} #{pretty_print ? '--pretty ' : ''}< #{CL_CONFIG} > #{CONFIG_IGN}"
    cmd = "#{ct_cmd} --platform=#{platform} #{pretty_print && '--pretty ' || ''}< #{CL_CONFIG} > #{CONFIG_IGN}"
    execute_cmd(cmd)
  end
end

# 3. vagrant 실행
# execute_cmd("vagrant up --provision")

$logger.close