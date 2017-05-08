require 'redic'

require_relative 'sentinels/version'

class Redic
  class Sentinels

    class UnreachableHosts < ArgumentError; end
    class UnknownMaster < ArgumentError; end

    attr_reader :sentinels, :master_name, :password, :db, :timeout, :client

    def initialize(options)
      @sentinels   = options.fetch(:sentinels)
      @master_name = options.fetch(:master_name)
      @password    = options[:password]
      @db          = options.fetch(:db, 0)
      @timeout     = options[:timeout]

      establish_connection
    end

    def call(*args)
      forward { client.call *args }
    end

    def call!(*args)
      forward { client.call! *args }
    end

    def queue(*args)
      forward { client.queue *args }
    end

    def clear
      forward { client.clear }
    end

    def commit
      buffer = client.buffer

      forward do
        client.buffer.replace(buffer)
        client.commit
      end
    end

    private

    def forward
      yield
    rescue Errno::ECONNREFUSED
      establish_connection
      retry
    end

    def establish_connection
      sentinels.each do |host|
        begin
          sentinel = Redic.new "redis://#{host}"

          ip, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', master_name
          raise UnknownMaster if ip.nil? && port.nil?

          @client = Redic.new "redis://#{password ? ":#{password}@" : ''}#{ip}:#{port}/#{db}"
          return

        rescue Errno::ECONNREFUSED
        end
      end

      raise UnreachableHosts
    end

  end
end