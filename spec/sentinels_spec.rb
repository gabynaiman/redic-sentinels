require_relative 'minitest_helper'

describe Redic::Sentinels do

  SENTINEL_VALID_HOSTS = [
    'localhost:26379',
    'localhost:26380',
    'localhost:26381'
  ].shuffle

  SENTINEL_INVALID_HOSTS = [
    'localhost:26382',
    'localhost:26383'
  ].shuffle

  SENTINEL_HOSTS = (SENTINEL_VALID_HOSTS + SENTINEL_INVALID_HOSTS).shuffle

  MASTER_NAME = 'mymaster'

  def disconnect(redis)
    redis.client.configure "redis://#{SENTINEL_INVALID_HOSTS.sample}"
  end

  describe 'Connection success' do

    let(:redis) { Redic::Sentinels.new sentinels: SENTINEL_HOSTS, master_name: MASTER_NAME }

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

    it 'clear' do
      redis.queue 'PING'
      redis.client.buffer.must_equal [['PING']]

      redis.clear
      redis.client.buffer.must_be_empty
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

    it 'Default DB' do
      redis.client.url.must_equal 'redis://127.0.0.1:16380/0'
    end

    it 'Custom DB' do
      redis = Redic::Sentinels.new sentinels: SENTINEL_HOSTS, master_name: MASTER_NAME, db: 7
      redis.client.url.must_equal 'redis://127.0.0.1:16380/7'
    end

    it 'Auth' do
      redis = Redic::Sentinels.new sentinels: SENTINEL_HOSTS, master_name: MASTER_NAME, password: 'pass'
      redis.client.url.must_equal 'redis://:pass@127.0.0.1:16380/0'
    end

  end

  describe 'Connection fail' do
    
    it 'Invalid hosts' do
      invalid_hosts = ['localhost:26382', 'localhost:26383']
      proc { Redic::Sentinels.new sentinels: invalid_hosts, master_name: MASTER_NAME }.must_raise Redic::Sentinels::UnreachableHosts
    end

    it 'Whithout hosts' do
      proc { Redic::Sentinels.new sentinels: [], master_name: MASTER_NAME }.must_raise Redic::Sentinels::UnreachableHosts
    end

    it 'Invalid master' do
      proc { Redic::Sentinels.new sentinels: SENTINEL_VALID_HOSTS, master_name: 'invalid_master' }.must_raise Redic::Sentinels::UnknownMaster
    end

  end

end