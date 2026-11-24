require_relative '../ruby/deskcite'
c = Deskcite::Client.new(ENV.fetch('DS_TEST_URL'), 'test-bearer', ca_file: ENV.fetch('DS_TEST_CA'))
Deskcite::OPERATIONS.each do |op,spec|
  next if ['refresh','document','question'].include?(op)
  r = c.call(op, spec['kind'] == 'json' ? {'text'=>'café & ?', 'q'=>'test', 'action'=>'calendar'} : {})
  raise 'bad response' unless r[:body]['ok']
end
raise 'id encoding' unless c.question('id/ ?#')[:body]['path'].end_with?('id%2F%20%3F%23')
raise 'binary document' unless c.document('/deskcite/documents/a%20b.pdf')[:body].bytes == [0,255,10]
[['__error__',503],['__redirect__',302]].each do |text,status|
  begin
    c.similar({'text'=>text})
    raise 'expected error'
  rescue Deskcite::Error => e
    raise 'error body/status lost' unless e.response[:status] == status && !e.response[:body].empty?
  end
end
['https://elsewhere.test/x','/deskcite/documents/%2e%2e/x','/deskcite/documents/a?x=1'].each do |path|
  begin
    c.document(path)
    raise 'invalid path accepted'
  rescue ArgumentError
  end
end
c.token = c.refresh[:body]['access_token']
raise 'rotation' unless c.status[:body]['credential'] == 'rotated'
messages = []
conn = c.events(->(m) { messages << m })
begin
  conn.recv
  raise 'event missing' unless messages[0]['type'] == 'import.done'
ensure
  conn.close
end
puts 'Ruby: HTTPS routes, bytes, errors, rotation, WSS passed'
