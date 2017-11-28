require 'redic'

require_relative 'sentinels/version'

class Redic
  class Sentinels

    class UnreachableHosts < ArgumentError; end
    class UnknownMaster < ArgumentError; end

    attr_reader :hosts, :master_name, :password, :db, :timeout

    def initialize(options)
      @hosts       = options.fetch(:hosts)
      @master_name = options.fetch(:master_name)
      @password    = options[:password]
      @db          = options.fetch(:db, 0)
      @timeout     = options[:timeout]
      @max_retries = options.fetch(:max_retries, 3)

      establish_connection
    end

    def call(*args)
      forward { redis.call *args }
    end

    def call!(*args)
      forward { redis.call! *args }
    end

    def queue(*args)
      forward { redis.queue *args }
    end

    def commit
      buffer = redis.buffer

      forward do
        redis.buffer.replace(buffer)
        redis.commit
      end
    end

    def buffer
      forward { redis.buffer }
    end

    def reset
      forward { redis.reset }
    end

    def clear
      forward { redis.clear }
    end

    def client
      forward { redis.client }
    end

    def url
      forward { redis.url }
    end

    private

    attr_reader :redis

    def forward
      yield.tap do |result|
        @retry_attempts = 0
      end
    rescue => ex
      @retry_attempts ||= 0
      if @retry_attempts < @max_retries
        establish_connection
        @retry_attempts += 1
        retry
      else
        raise ex
      end
    end

    def establish_connection
      hosts.each do |host|
        begin
          sentinel = Redic.new "redis://#{host}"

          ip, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', master_name
          raise UnknownMaster if ip.nil? && port.nil?

          @redis = Redic.new *["redis://#{password ? ":#{password}@" : ''}#{ip}:#{port}/#{db}", timeout].compact
          return

        rescue Errno::ECONNREFUSED
        end
      end

      raise UnreachableHosts
    end

  end
end