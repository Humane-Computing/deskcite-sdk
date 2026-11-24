require 'json'
require 'uri'
require 'net/http'
require 'openssl'

module Deskcite
  OPERATIONS = JSON.parse(File.read(File.join(__dir__, 'operations.json'))).freeze
  class Error < StandardError
    attr_reader :response
    def initialize(response)
      @response = response
      super("Deskcite HTTP #{response[:status]}")
    end
  end
  class Client
    def initialize(origin, token, transport: nil, timeout: 30, ca_file: nil, mesgd: nil)
      u = URI(origin)
      raise ArgumentError, 'expected an HTTPS origin' unless u.is_a?(URI::HTTPS) && u.host && !u.userinfo && ['', '/'].include?(u.path) && !u.query && !u.fragment
      @origin, @uri, @timeout, @transport, @ca_file, @mesgd = origin.sub(%r{/$}, ''), u, timeout, transport, ca_file, mesgd
      self.token = token
    end
    def token=(token)
      raise ArgumentError, 'expected bearer token' unless token.is_a?(String) && token.match?(/\A[\x21-\x7e]+\z/)
      @token = token
    end
    def call(operation, args = {})
      raise ArgumentError, 'expected argument map' unless args.is_a?(Hash)
      spec = OPERATIONS.fetch(operation.to_s)
      path = spec['path']
      if spec['kind'] == 'id'
        id = args.fetch('id')
        raise ArgumentError, 'expected id' unless id.is_a?(String) && !id.empty?
        path += URI.encode_www_form_component(id).gsub('+', '%20')
      end
      if spec['kind'] == 'document'
        path = args.fetch('path')
        decoded = URI::DEFAULT_PARSER.unescape(path)
        raise ArgumentError, 'expected a Deskcite document URL path' unless path.start_with?('/deskcite/documents/') && !path.match?(/[?#\s\\]/) && !decoded.match?(/[\x00-\x1f\x7f\\]/) && !decoded.split('/').any? { |s| ['.', '..'].include?(s) }
      end
      raise ArgumentError, 'operation takes no arguments' if spec['kind'] == 'none' && !args.empty?
      status, headers, raw = (@transport || method(:https)).call(spec['method'], path, spec['kind'] == 'json' ? args : nil, @token)
      response = {status: status, headers: headers, body: raw}
      raise Error.new(response) unless (200...300).cover?(status)
      response[:body] = JSON.parse(raw) unless spec['kind'] == 'document'
      response
    end
    def question(id); call(:question, {'id' => id}); end
    def document(path); call(:document, {'path' => path}); end
    OPERATIONS.each_key do |op|
      define_method(op) { |args = {}| call(op, args) } unless instance_methods(false).include?(op.to_sym)
    end
    def events(handler, **options)
      unless @mesgd
        require File.join(ENV.fetch('MESGD_SDK'), 'ruby/mesgd')
      end
      context = OpenSSL::SSL::SSLContext.new
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
      context.verify_hostname = true
      context.ca_file = @ca_file if @ca_file
      # Require hostname checking during the TLS handshake as well as peer trust.
      conn = (@mesgd || ::Mesgd).connect(@origin.sub(/^https:/, 'wss:') + '/deskcite/events', **options, token: @token, ssl_context: context)
      conn.on('*', &handler)
      conn
    end
    private
    def https(method, path, body, token)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = @ca_file if @ca_file
      http.open_timeout = http.read_timeout = @timeout
      http.max_retries = 0
      request = (method == 'GET' ? Net::HTTP::Get : Net::HTTP::Post).new(path)
      request['Accept'], request['Authorization'] = 'application/json', 'Bearer ' + token
      if body
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body)
      end
      r = http.request(request)
      [r.code.to_i, r.to_hash, r.body || ''.b]
    end
  end
end
