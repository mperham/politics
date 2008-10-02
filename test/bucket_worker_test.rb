require 'test_helper'

class BucketWorkerTest < Test::Unit::TestCase
  
  context "bucket workers" do
    setup do
      @harness = Class.new
      @harness.send(:include, Politics::BucketWorker)
      @harness.any_instance.stubs(:loop?).returns(false)
      @worker = @harness.new
    end

    should "have instance property accessors" do
      assert @worker.bucket_count = 20
      assert_equal 20, @worker.bucket_count
    end

    should 'register correctly' do
      @worker.register_worker('testing')
      @worker.register_worker('testing', ['localhost:5555,localhost:12121'])
    end
    
    should 'process a bucket' do
      @worker.register_worker('testing')
      @worker.starling_client.expects(:get).returns(4)
      @worker.starling_client.expects(:set).with('testing', 4).returns(nil)
      processed = false
      @worker.process_bucket do |bucket|
        assert_equal 4, bucket
        processed = true
      end
      assert processed
    end

    should 'not allow processing without block' do
      assert_raises ArgumentError do
        @worker.register_worker('hello')
        @worker.process_bucket
      end
    end

    should 'not allow processing without registration' do
      assert_raises ArgumentError do
        @worker.process_bucket do
          fail 'Should not process!'
        end
      end
    end

  end
end