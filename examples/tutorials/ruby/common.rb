require 'tempfile'
require_relative '../../../ruby/deskcite'
def load_client
  file = ENV['DESKCITE_TOKEN_FILE']
  token = file ? File.read(file).strip : ENV.fetch('DESKCITE_TOKEN')
  [Deskcite::Client.new(ENV.fetch('DESKCITE_URL'), token, ca_file: ENV['DESKCITE_CA']), token]
end
def store_token(token)
  target = ENV.fetch('DESKCITE_TOKEN_FILE')
  Tempfile.create('.rotate-', File.dirname(target)) do |file|
    file.chmod(0600)
    file.write(token + "\n"); file.flush; file.fsync
    File.rename(file.path, target)
  end
end
