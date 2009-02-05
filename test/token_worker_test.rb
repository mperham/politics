require 'test_helper'

class TokenWorkerTest < Test::Unit::TestCase
  
  context "token workers" do
    setup do
      @harness = Class.new
      @harness.send(:include, Politics::TokenWorker)
      @harness.any_instance.stubs(:cleanup)
      @harness.any_instance.stubs(:loop?).returns(false)
      @harness.any_instance.stubs(:pause_until_expiry)
      @harness.any_instance.stubs(:relax)

      @worker = @harness.new
    end

    should "test_instance_property_accessors" do
      assert @worker.iteration_length = 20
      assert_equal 20, @worker.iteration_length
    end

    should 'test_tracks_a_registered_singleton' do
      assert_nil @worker.class.worker_instance
      @worker.register_worker('testing')
      assert_equal @worker.class.worker_instance, @worker
    end
    
    should 'not process if they are not leader' do
      @worker.expects(:nominate)
      @worker.expects(:leader?).returns(false)
      @worker.register_worker('testing')
      @worker.process do
        assert false
      end
    end

    should 'handle unexpected MemCache errors' do
      @worker.expects(:nominate)
      @worker.expects(:leader?).raises(MemCache::MemCacheError)
      Politics::log.expects(:error).times(3)

      @worker.register_worker('testing')
      @worker.process do
        assert false
      end
    end

    should 'process if they are leader' do
      @worker.expects(:nominate)
      @worker.expects(:leader?).returns(true)
      @worker.register_worker('testing')

      worked = 0
      @worker.process do
        worked += 1
      end

      assert_equal 1, worked
    end
    
    should 'not allow processing without registration' do
      assert_raises ArgumentError do
        @worker.process
      end
    end

    should 'not allow processing by old instances' do
      @worker.register_worker('testing')

      foo = @worker.class.new
      foo.register_worker('testing')
      
      assert_raises SecurityError do
        @worker.process
      end
    end
  end
end