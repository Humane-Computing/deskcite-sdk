require_relative 'common'
ENV.fetch('DESKCITE_TOKEN_FILE')
client, old = load_client
replacement = client.refresh[:body].fetch('access_token')
store_token(replacement)
client.token = replacement
client.status
client.token = old
begin
  client.status
  raise 'Old bearer was unexpectedly accepted'
rescue Deskcite::Error => error
  raise unless error.response[:status] == 401
end
client.token = replacement
puts 'Credential rotated and saved; replacement works; old bearer rejected.'
