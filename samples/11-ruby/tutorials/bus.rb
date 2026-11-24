require 'json'
require File.join(ENV.fetch('MESGD_SDK'), 'ruby/mesgd')

role = ARGV.fetch(0, '')
abort 'usage: ruby pubsub.rb server|client' unless %w[server client].include?(role)
address = role == 'server' ? 'service' : 'client'
origin = ENV.fetch('MESGD_WSS').sub(%r{/$}, '')
context = OpenSSL::SSL::SSLContext.new
context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER, verify_hostname: true)
context.ca_file = ENV['MESGD_CA'] if ENV['MESGD_CA']
conn = Mesgd.connect("#{origin}/to=#{address}", token: ENV['MESGD_TOKEN'],
                     ssl_context: context)
done = false
conn.on(role == 'server' ? 'echo.request' : 'echo.reply') do |message|
  if role == 'server'
    puts 'agent received: ' + JSON.generate(message.fetch('body'))
    conn.send({ 'to' => message.fetch('from'), 'from' => 'service',
                'type' => 'echo.reply', 'body' => message.fetch('body') })
  else
    puts JSON.generate(message.fetch('body'))
    done = true
  end
end
$stdout.sync = true
puts "ready: #{role}"
begin
  if role == 'client'
    conn.send({ 'to' => 'service', 'from' => 'client',
                'type' => 'echo.request', 'body' => { 'text' => 'hello' } })
  end
  conn.recv until done
ensure
  conn.close
end
