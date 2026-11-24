require_relative 'common'
client, = load_client
result = client.similar('text' => 'How do I upload a document in Deskcite?', 'n' => 3)
result[:body].fetch('rows').each do |row|
  puts row.fetch('answer')
  puts "Source: #{row.fetch('path')}"
end
