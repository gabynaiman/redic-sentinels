require_relative 'minitest_helper'

describe Redic::Sentinels do

  VALID_HOSTS = [
    'localhost:26379',
    'localhost:26380',
    'localhost:26381'
  ].shuffle

  INVALID_HOSTS = [
    'localhost:26382',
    'localhost:26383'
  ].shuffle

  HOSTS = (VALID_HOSTS + INVALID_HOSTS).shuffle

  MASTER_NAME = 'mymaster'

  def disconnect(redis)
    redis.client.configure "redis://#{INVALID_HOSTS.sample}", 10_000_000
  end

  describe 'Connection success' do

    let(:redis) { Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME }

    let(:sentinel) { Redic.new "redis://#{VALID_HOSTS.first}" }
    
    after do
      _, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', MASTER_NAME
      master = Redic.new "redis://localhost:#{port}"
      master.call! 'FLUSHDB'
    end

    it 'call' do
      redis.call('PING').must_equal 'PONG'
      redis.call('INVALID_COMMAND').must_be_instance_of RuntimeError
    end

    it 'call!' do
      redis.call!('PING').must_equal 'PONG'
      proc { redis.call! 'INVALID_COMMAND' }.must_raise RuntimeError
    end

    it 'queue/commit' do
      redis.queue('PING').must_equal [['PING']]
      redis.queue('PING').must_equal [['PING'], ['PING']]
      redis.commit.must_equal ['PONG', 'PONG']
    end

    it 'clear/reset' do
      redis.queue 'PING'
      redis.buffer.must_equal [['PING']]

      redis.clear
      redis.buffer.must_be_empty

      redis.queue 'PING'
      redis.buffer.must_equal [['PING']]

      redis.reset
      redis.buffer.must_be_empty
    end

    it 'get/set' do
      redis.call!('GET', 'key1').must_be_nil
      redis.call! 'SET', 'key1', 'value1'
      redis.call!('GET', 'key1').must_equal 'value1'
    end

    it 'Retry on connection failures' do
      redis.call('PING').must_equal 'PONG'

      disconnect redis

      redis.call('PING').must_equal 'PONG'
      redis.queue('PING').must_equal [['PING']]

      disconnect redis

      redis.queue('PING').must_equal [['PING'], ['PING']]
      redis.commit.must_equal ['PONG', 'PONG']
    end

    it 'Retry on Master change' do
      redis.call('PING').must_equal 'PONG'

      redis.call('PING').must_equal 'PONG'
      redis.queue('PING').must_equal [['PING']]

      sentinel.call 'SENTINEL', 'failover', 'mymaster'

      redis.call('PING').must_equal 'PONG'
      redis.queue('PING').must_equal [['PING'], ['PING']]

      redis.queue('PING').must_equal [['PING'], ['PING'], ['PING']]
      redis.commit.must_equal ['PONG', 'PONG', 'PONG']
    end

    it 'Default DB' do
      ip, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', MASTER_NAME
      redis.url.must_equal "redis://#{ip}:#{port}/0"
    end

    it 'Custom DB' do
      ip, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', MASTER_NAME
      redis = Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME, db: 7
      redis.url.must_equal "redis://#{ip}:#{port}/7"
    end

    it 'Auth' do
      ip, port = sentinel.call 'SENTINEL', 'get-master-addr-by-name', MASTER_NAME
      redis = Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME, password: 'pass'
      redis.url.must_equal "redis://:pass@#{ip}:#{port}/0"
    end

  end

  describe 'Connection fail' do
    
    it 'Invalid hosts' do
      invalid_hosts = ['localhost:26382', 'localhost:26383']
      proc { Redic::Sentinels.new hosts: invalid_hosts, master_name: MASTER_NAME }.must_raise Redic::Sentinels::UnreachableHosts
    end

    it 'Whithout hosts' do
      proc { Redic::Sentinels.new hosts: [], master_name: MASTER_NAME }.must_raise Redic::Sentinels::UnreachableHosts
    end

    it 'Invalid master' do
      proc { Redic::Sentinels.new hosts: VALID_HOSTS, master_name: 'invalid_master' }.must_raise Redic::Sentinels::UnknownMaster
    end

  end

end