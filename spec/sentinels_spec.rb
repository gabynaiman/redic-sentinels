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

  after do
    master = Redic.new 'redis://localhost:16379'
    master.call! 'FLUSHDB'
  end

  describe 'Connection success' do

    let(:redis) { Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME }

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

    it 'Default DB' do
      redis.url.must_equal 'redis://127.0.0.1:16379/0'
    end

    it 'Custom DB' do
      redis = Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME, db: 7
      redis.url.must_equal 'redis://127.0.0.1:16379/7'
    end

    it 'Auth' do
      redis = Redic::Sentinels.new hosts: HOSTS, master_name: MASTER_NAME, password: 'pass'
      redis.url.must_equal 'redis://:pass@127.0.0.1:16379/0'
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