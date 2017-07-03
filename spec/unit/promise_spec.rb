# encoding: utf-8

require 'spec_helper'

describe Promise do
  subject { Promise.new }

  let(:value) { double('value') }
  let(:other_value) { double('other_value') }

  let(:backtrace) { caller }
  let(:reason) do
    StandardError.new('reason').tap { |err| err.set_backtrace(backtrace) }
  end
  let(:other_reason) do
    StandardError.new('other_reason').tap { |err| err.set_backtrace(caller) }
  end

  let(:dummy) { Object.new }
  let(:sentinel) { Object.new }

  describe '2.2.6: `then` may be called multiple times on the same promise.' do
    describe '2.2.6.1: If/when `promise` is fulfilled, all respective `onFulfilled` callbacks must execute in the order of their originating calls to `then`.' do
      it 'on an immediately fulfilled promise' do
        promise = Promise.new.fulfill(sentinel)

        called = []
        promise.then { called << 1 }
        promise.then { called << 2 }
        promise.then { called << 3 }

        expect(called).to eq([1, 2, 3])
      end

      it 'on an eventually-fulfilled promise' do
        promise = Promise.new

        called = []
        promise.then { called << 1 }
        promise.then { called << 2 }
        promise.then { called << 3 }

        promise.fulfill(sentinel)

        expect(called).to eq([1, 2, 3])
      end
    end
  end

  describe '2.2.7: `then` must return a promise' do
    it 'returns a promise' do
      promise1 = Promise.new
      promise2 = promise1.then

      expect(promise2).to be_an_instance_of(Promise)
    end

    describe '2.2.7.3: If `onFulfilled` is not a function and `promise1` is fulfilled' do
      it '`promise2` must be fulfilled with the same value' do
        promise1 = Promise.new.fulfill(sentinel)
        promise2 = promise1.then

        expect(promise2.value).to equal(sentinel)
      end
    end

    describe '2.2.7.3: If `onRejected` is not a function and `promise1` is rejected' do
      it '`promise2` must be rejected with the same value' do
        promise1 = Promise.new.reject(sentinel)
        promise2 = promise1.then

        expect(promise2.reason).to equal(sentinel)
      end
    end
  end

  describe '2.3.2: If `x` is a promise, adopt its state' do
    describe '2.3.2.1: If `x` is pending, `promise` must remain pending until `x` is fulfilled or rejected.' do
      it 'via return from from a fulfilled promise' do
        x = Promise.new
        promise = Promise.new.fulfill(dummy).then { x }

        expect(promise).not_to be_fulfilled
        expect(promise).not_to be_rejected

        expect(promise).to be_pending
      end

      it 'via return from from a rejected promise' do
        x = Promise.new
        promise = Promise.new.reject(dummy).then(->(_) {}, ->(_) { x })

        expect(promise).not_to be_fulfilled
        expect(promise).not_to be_rejected

        expect(promise).to be_pending
      end
    end

    describe '2.3.2.2: If/when `x` is fulfilled, fulfill `promise` with the same value.' do
      describe '`x` is already-fulfilled' do
        it 'via return from from a fulfilled promise' do
          x = Promise.new.fulfill(sentinel)
          promise = Promise.new.fulfill(dummy).then { x }

          value = nil
          promise.then { |v| value = v }

          expect(value).to equal(sentinel)
        end

        it 'via return from from a rejected promise' do
          x = Promise.new.fulfill(sentinel)
          promise = Promise.new.reject(dummy).then(->(_) {}, ->(_) { x })

          value = nil
          promise.then { |v| value = v }

          expect(value).to equal(sentinel)
        end
      end

      describe '`x` is eventually-fulfilled' do
        it 'via return from from a fulfilled promise' do
          x = Promise.new
          promise = Promise.new.fulfill(dummy).then { x }

          value = nil
          promise.then { |v| value = v }
          x.fulfill(sentinel)

          expect(value).to equal(sentinel)
        end

        it 'via return from from a rejected promise' do
          x = Promise.new
          promise = Promise.new.reject(dummy).then(->(_) {}, ->(_) { x })

          value = nil
          promise.then { |v| value = v }
          x.fulfill(sentinel)

          expect(value).to equal(sentinel)
        end
      end
    end

    describe '2.3.2.3: If/when `x` is rejected, reject `promise` with the same reason.' do
      describe '`x` is already-rejected' do
        it 'via return from from a fulfilled promise' do
          x = Promise.new.reject(sentinel)
          promise = Promise.new.fulfill(dummy).then { x }

          error = nil
          promise.then(->(_) {}, ->(e) { error = e })

          expect(error).to equal(sentinel)
        end

        it 'via return from from a rejected promise' do
          x = Promise.new.reject(sentinel)
          promise = Promise.new.reject(dummy).then(->(_) {}, ->(_) { x })

          error = nil
          promise.then(->(_) {}, ->(e) { error = e })

          expect(error).to equal(sentinel)
        end
      end

      describe '`x` is eventually-rejected' do
        it 'via return from from a fulfilled promise' do
          x = Promise.new
          promise = Promise.new.fulfill(dummy).then { x }

          error = nil
          promise.then(->(_) {}, ->(e) { error = e })
          x.reject(sentinel)

          expect(error).to equal(sentinel)
        end

        it 'via return from from a rejected promise' do
          x = Promise.new
          promise = Promise.new.reject(dummy).then(->(_) {}, ->(_) { x })

          error = nil
          promise.then(->(_) {}, ->(e) { error = e })
          x.reject(sentinel)

          expect(error).to equal(sentinel)
        end
      end
    end
  end

  describe '3.1.1 pending' do
    it 'transitions to fulfilled' do
      subject.fulfill(value)
      expect(subject).to be_fulfilled
    end

    it 'transitions to rejected' do
      subject.reject(reason)
      expect(subject).to be_rejected
    end
  end

  describe '3.1.2 fulfilled' do
    it 'does not transition to other states' do
      subject.fulfill(value)
      subject.reject(reason)
      expect(subject).to be_fulfilled
    end

    it 'has a value' do
      subject.fulfill(value)
      expect(subject.value).to eq(value)

      subject.fulfill(other_value)
      expect(subject.value).to eq(value)
    end
  end

  describe '3.1.3 rejected' do
    it 'does not transition to other states' do
      subject.reject(reason)
      subject.fulfill(value)
      expect(subject).to be_rejected
    end

    it 'has a reason' do
      subject.reject(reason)
      expect(subject.reason).to eq(reason)

      subject.reject(other_reason)
      expect(subject.reason).to eq(reason)
    end
  end

  describe '3.2.1 on_fulfill' do
    it 'is optional' do
      subject.then
      subject.fulfill(value)
    end
  end

  describe '3.2.1 on_reject' do
    it 'is optional' do
      subject.then(proc { |_| })
      subject.reject(reason)
    end
  end

  describe '3.2.2 on_fulfill' do
    it 'is called after promise is fulfilled' do
      fulfilled = nil
      subject.then(proc { |_| fulfilled = subject.fulfilled? })

      subject.fulfill(value)
      expect(fulfilled).to eq(true)
    end

    it 'is called with fulfillment value' do
      result = nil
      subject.then(proc { |val| result = val })

      subject.fulfill(value)
      expect(result).to eq(value)
    end

    it 'is called not more than once' do
      called = 0
      subject.then(proc { |_| called += 1 })

      subject.fulfill(value)
      subject.fulfill(value)
      expect(called).to eq(1)
    end

    it 'is not called if on_reject has been called' do
      called = false
      subject.then(proc { |_| called = true })

      subject.reject(reason)
      expect(called).to eq(false)
    end

    it 'can be passed as a block' do
      result = nil
      subject.then { |val| result = val }

      subject.fulfill(value)
      expect(result).to eq(value)
    end

    it 'takes precedence over block' do
      result = nil
      subject.then(proc { |_| result = :arg }) { |_| result = :block }

      subject.fulfill(value)
      expect(result).to be(:arg)
    end
  end

  describe '3.2.3 on_reject' do
    it 'is called after promise is rejected' do
      rejected = nil
      subject.then(nil, proc { |_| rejected = subject.rejected? })

      subject.reject(reason)
      expect(rejected).to eq(true)
    end

    it 'is called with rejection reason' do
      result = nil
      subject.then(nil, proc { |reas| result = reas })

      subject.reject(reason)
      expect(result).to eq(reason)
    end

    it 'is called not more than once' do
      called = 0
      subject.then(nil, proc { |_| called += 1 })

      subject.reject(reason)
      subject.reject(reason)
      expect(called).to eq(1)
    end

    it 'is not called if on_fulfill has been called' do
      called = false
      subject.then(nil, proc { |_| called = true })

      subject.fulfill(value)
      expect(called).to eq(false)
    end
  end

  describe '3.2.4' do
    it 'returns before on_fulfill or on_reject is called' do
      called = false
      p1 = DelayedPromise.new
      p2 = p1.then { called = true }

      p1.fulfill(42)

      expect(called).to eq(false)
      DelayedPromise.call_deferred
      expect(called).to eq(true)
      expect(p2).to be_fulfilled
    end
  end

  describe '3.2.5' do
    it 'calls multiple on_fulfill callbacks in order of definition' do
      order = []
      on_fulfill = proc do |i, val|
        order << i
        expect(val).to eq(value)
      end

      subject.then(on_fulfill.curry[1])
      subject.then(on_fulfill.curry[2])

      subject.fulfill(value)
      subject.then(on_fulfill.curry[3])

      expect(order).to eq([1, 2, 3])
    end

    it 'calls all on_fulfill callbacks even if one raises an exception' do
      order = []
      on_fulfill = proc do |i, val|
        order << i
        expect(val).to eq(value)
      end

      subject.then(on_fulfill.curry[1])
      subject.then do |_|
        order << 2
        raise 'middle then error'
      end
      subject.then(on_fulfill.curry[3])

      subject.fulfill(value)

      expect(order).to eq([1, 2, 3])
    end

    it 'calls multiple on_reject callbacks in order of definition' do
      order = []
      on_reject = proc do |i, reas|
        order << i
        expect(reas).to eq(reason)
      end

      subject.then(nil, on_reject.curry[1])
      subject.then(nil, on_reject.curry[2])

      subject.reject(reason)
      subject.then(nil, on_reject.curry[3])

      expect(order).to eq([1, 2, 3])
    end
  end

  describe '3.2.6' do
    let(:error) { StandardError.new }
    let(:returned_promise) { Promise.new }

    it 'returns promise2' do
      expect(subject.then).to be_a(Promise)
      expect(subject.then).not_to eq(subject)
    end

    it 'fulfills promise2 with value returned by on_fulfill' do
      promise2 = subject.then(proc { |_| other_value })
      subject.fulfill(value)

      expect(promise2).to be_fulfilled
      expect(promise2.value).to eq(other_value)
    end

    it 'fulfills promise2 with value returned by on_reject' do
      promise2 = subject.then(nil, proc { |_| other_value })
      subject.reject(reason)

      expect(promise2).to be_fulfilled
      expect(promise2.value).to eq(other_value)
    end

    it 'rejects promise2 with error raised by on_fulfill' do
      promise2 = subject.then(proc { |_| raise error })
      subject.fulfill(value)

      expect(promise2).to be_rejected
      expect(promise2.reason).to eq(error)
    end

    it 'rejects promise2 with error raised by on_reject' do
      promise2 = subject.then(nil, proc { |_| raise error })
      subject.reject(reason)

      expect(promise2).to be_rejected
      expect(promise2.reason).to eq(error)
    end

    describe 'on_fulfill returns promise' do
      it 'makes promise2 assume fulfilled state of returned promise' do
        promise2 = subject.then(proc { |_| returned_promise })

        subject.fulfill(value)
        expect(promise2).to be_pending

        returned_promise.fulfill(other_value)
        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(other_value)
      end

      it 'makes promise2 assume rejected state of returned promise' do
        promise2 = subject.then(proc { |_| returned_promise })

        subject.fulfill(value)
        expect(promise2).to be_pending

        returned_promise.reject(other_reason)
        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(other_reason)
      end
    end

    describe 'on_reject returns promise' do
      it 'makes promise2 assume fulfilled state of returned promise' do
        promise2 = subject.then(nil, proc { |_| returned_promise })

        subject.reject(reason)
        expect(promise2).to be_pending

        returned_promise.fulfill(other_value)
        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(other_value)
      end

      it 'makes promise2 assume rejected state of returned promise' do
        promise2 = subject.then(nil, proc { |_| returned_promise })

        subject.reject(reason)
        expect(promise2).to be_pending

        returned_promise.reject(other_reason)
        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(other_reason)
      end
    end

    describe 'without on_fulfill' do
      it 'fulfill promise2 with fulfillment value' do
        promise2 = subject.then
        subject.fulfill(value)

        expect(promise2).to be_fulfilled
        expect(promise2.value).to eq(value)
      end
    end

    describe 'without on_reject' do
      it 'rejects promise2 with rejection reason' do
        promise2 = subject.then
        subject.reject(reason)

        expect(promise2).to be_rejected
        expect(promise2.reason).to eq(reason)
      end
    end
  end

  describe 'a Promise A that is following a Promise B' do
    it "is instantly fulfilled with B's fulfillment value if B is fulfilled" do
      b = Promise.resolve(sentinel)
      a = Promise.resolve(b)

      expect(a.value).to equal(sentinel)
      expect(a.value).to equal(b.value)
    end

    it "is eventually-fulfilled with B's fulfillment value if B is fulfilled" do
      b = Promise.new
      a = Promise.resolve(b)

      expect(a).to be_pending

      b.fulfill(sentinel)

      expect(a.value).to equal(sentinel)
      expect(a.value).to equal(b.value)
    end

    it "is instantly fulfilled with B's parent fulfillment value when B was fulfilled with a parent" do
      parent = Promise.resolve(sentinel)

      b = Promise.resolve(parent)
      a = Promise.resolve(b)

      expect(a.value).to equal(sentinel)
      expect(a.value).to equal(b.value)
      expect(a.value).to equal(parent.value)
    end

    it "is eventually-fulfilled with B's parent fulfillment value when B was fulfilled with a parent" do
      parent = Promise.new

      b = Promise.resolve(parent)
      a = Promise.resolve(b)

      parent.fulfill(sentinel)

      expect(a.value).to equal(sentinel)
      expect(a.value).to equal(b.value)
      expect(a.value).to equal(parent.value)
    end
  end

  describe 'nested promise chains' do
    it 'should correctly fulfill all nested promises' do
      parent = Promise.new
      b = Promise.new

      called = []

      parent.then { called << 1 }
      b.then { called << 2 }
      parent.then { called << 3 }
      b.then { called << 4 }

      parent.fulfill(b)

      b.then { called << 5 }
      parent.then { called << 6 }

      b.fulfill(sentinel)

      # The order here is not actually specified by the Promises/A+ spec
      expect(called).to eq([2, 4, 1, 3, 6, 5])
    end
  end

  describe 'extras' do
    describe '#rescue' do
      it 'provides an on_reject callback' do
        result = nil
        subject.rescue { |reas| result = reas }

        subject.reject(reason)
        expect(result).to eq(reason)
        expect(subject.reason).to eq(reason)
      end
    end

    describe '#catch' do
      it 'provides an on_reject callback' do
        result = nil
        subject.catch { |reas| result = reas }

        subject.reject(reason)
        expect(result).to eq(reason)
        expect(subject.reason).to eq(reason)
      end
    end

    describe '#progress' do
      let(:status) { double('status') }

      it 'calls the callbacks in the order of calls to #on_progress' do
        order = []
        block = proc do |i, stat|
          order << i
          expect(stat).to eq(status)
        end

        subject.on_progress(&block.curry[1])
        subject.on_progress(&block.curry[2])
        subject.on_progress(&block.curry[3])
        subject.progress(status)

        expect(order).to eq([1, 2, 3])
      end

      it 'does not call back unless pending' do
        called = false
        subject.on_progress { |_| called = true }
        subject.fulfill(value)

        subject.progress(status)
        expect(called).to eq(false)
      end
    end

    describe '#fulfill' do
      it 'returns itself to allow chaining' do
        expect(subject.fulfill(nil)).to be(subject)
      end

      it 'does not require a value' do
        subject.fulfill
        expect(subject.value).to be(nil)
      end

      it 'assumes the state of a given promise' do
        promise = Promise.new

        subject.fulfill(promise)
        expect(subject).to be_pending
        promise.fulfill(123)

        expect(subject).to be_fulfilled
        expect(subject.value).to eq(123)
      end
    end

    describe '#reject' do
      it 'returns itself for easy chaning' do
        expect(subject.reject(nil)).to be(subject)
      end

      it 'does not require a reason' do
        subject.reject
        expect(subject.reason).to be_a(Promise::Error)
      end

      it 'sets the backtrace' do
        subject.reject
        expect(subject.reason.backtrace.join)
          .to include(__FILE__ + ':' + (__LINE__ - 2).to_s)
      end

      it 'leaves backtrace if already set' do
        subject.reject(reason)
        expect(subject.reason.backtrace).to eq(backtrace)
      end

      it 'instantiates exception class' do
        subject.reject(Exception)
        expect(subject.reason).to be_a(Exception)
      end

      it 'instantiates exception subclasses' do
        subject.reject(RuntimeError)
        expect(subject.reason).to be_a(RuntimeError)
      end

      it "doesn't instantiate non-error classes" do
        subject.reject(Hash)
        expect(subject.reason).to eq(Hash)
      end
    end

    describe '#sync' do
      it 'waits for fulfillment' do
        allow(subject).to receive(:wait) { subject.fulfill(value) }
        expect(subject.sync).to be(value)
      end

      it 'waits for rejection' do
        allow(subject).to receive(:wait) { subject.reject(reason) }
        expect { subject.sync }.to raise_error(reason)
      end

      it 'waits if pending' do
        subject.fulfill(value)
        expect(subject).not_to receive(:wait)
        expect(subject.sync).to be(value)
      end

      it 'waits for source by default' do
        PromiseLoader.lazy_load(subject) { subject.fulfill(1) }
        p2 = subject.then { |v| v + 1 }
        expect(p2).to be_pending
        expect(p2.sync).to eq(2)
        expect(p2.source).to eq(nil)
      end

      it 'waits for source that is fulfilled with a promise' do
        PromiseLoader.lazy_load(subject) { subject.fulfill(1) }
        p2 = subject.then do |v|
          Promise.new.tap do |p3|
            PromiseLoader.lazy_load(p3) { p3.fulfill(v + 1) }
          end
        end
        expect(p2).to be_pending
        expect(p2.sync).to eq(2)
        expect(p2.source).to eq(nil)
      end

      it 'waits for source rejection' do
        PromiseLoader.lazy_load(subject) { subject.reject(reason) }
        p2 = subject.then { |v| v + 1 }
        expect { p2.sync }.to raise_error(reason)
        expect(p2.source).to eq(nil)
      end

      it 'raises for promise without a source by default' do
        expect { subject.sync }.to raise_error(Promise::BrokenError)
      end

      it 'raises if source.wait leaves promise pending' do
        PromiseLoader.lazy_load(subject) {}
        expect { subject.sync }.to raise_error(Promise::BrokenError)
      end
    end

    describe '.sync' do
      it 'returns non-promise argument' do
        expect(Promise.sync(42)).to eq(42)
      end

      it 'calls sync on promise argument' do
        PromiseLoader.lazy_load(subject) { subject.fulfill(123) }
        expect(Promise.sync(subject)).to eq(123)
      end

      it 'calls sync on promise of another class' do
        promise = Class.new(Promise).resolve('a')
        expect(Class.new(Promise).sync(promise)).to eq('a')
      end
    end

    describe '.resolve' do
      it 'returns a fulfilled promise from a non-promise' do
        promise = Promise.resolve(123)
        expect(promise.fulfilled?).to eq(true)
        expect(promise.value).to eq(123)
      end

      it 'returns a given promise' do
        promise = Promise.new
        new_promise = Promise.resolve(promise)
        expect(new_promise.object_id).to eq(promise.object_id)
      end

      it 'returns a given promise of a subclass of itself' do
        promise = DelayedPromise.new
        new_promise = Promise.resolve(promise)
        expect(new_promise.object_id).to eq(promise.object_id)
      end

      it 'assumes the state of a given promise of another class' do
        promise = Promise.new
        new_promise = DelayedPromise.resolve(promise)
        expect(new_promise).to be_an_instance_of(DelayedPromise)
        expect(new_promise).to be_pending
        promise.fulfill(42)
        expect(new_promise).to be_fulfilled
        expect(new_promise.value).to eq(42)
      end

      it 'can be passed no argument' do
        promise = Promise.resolve
        expect(promise.fulfilled?).to eq(true)
        expect(promise.value).to eq(nil)
      end
    end

    describe '.all' do
      it 'returns a fulfilled promise for an array with no promises' do
        obj = Object.new
        promise = Promise.all([1, 'b', obj])
        expect(promise.fulfilled?).to eq(true)
        expect(promise.value).to eq([1, 'b', obj])
      end

      it 'fulfills the result when all args are fulfilled' do
        p1 = Promise.new
        p2 = Promise.new

        result = Promise.all([p1, p2, 3])

        expect(result).to be_pending
        p2.fulfill('b')
        expect(result).to be_pending
        p1.fulfill(:a)
        expect(result).to be_fulfilled
        expect(result.value).to eq([:a, 'b', 3])
      end

      it 'leaves result pending if only the first input arg is fulfilled' do
        p1 = Promise.new
        p1.fulfill('a')
        p2 = Promise.new

        result = Promise.all([p1, p2])

        expect(result).to be_pending
        p2.fulfill(:b)
        expect(result).to be_fulfilled
        expect(result.value).to eq(['a', :b])
      end

      it 'rejects the result when any arg is rejected' do
        reason = RuntimeError.new('p1 failed')

        p1 = Promise.new
        p2 = Promise.new.reject(reason)

        result = Promise.all([p1, p2])

        expect(result).to be_rejected
        expect(result.reason).to eq(reason)
      end

      it 'rejects the result when any arg is eventually-rejected' do
        reason = RuntimeError.new('p1 failed')

        p1 = Promise.new
        p2 = Promise.new

        result = Promise.all([p1, p2])

        expect(result).to be_pending
        p1.reject(reason)
        expect(result).to be_rejected
        expect(result.reason).to eq(reason)
      end

      it 'returns an instance of the class it is called on' do
        p1 = Promise.new

        result = DelayedPromise.all([p1, 2])

        expect(result).to be_an_instance_of(DelayedPromise)
        p1.fulfill(1.0)
        expect(result.sync).to eq([1.0, 2])
      end

      it 'returns an instance of the class it is called on' do
        p1 = DelayedPromise.new

        result = DelayedPromise.all([p1, 2])

        expect(result).to be_pending
        p1.fulfill(1.0)
        expect(result.sync).to eq([1.0, 2])
      end

      it 'returns a promise that can sync promises of another class' do
        p1 = DelayedPromise.new
        DelayedPromise.deferred << -> { p1.fulfill('a') }

        result = Promise.all([p1, Promise.resolve(:b), 3])

        expect(result).to be_pending
        expect(result.sync).to eq(['a', :b, 3])
      end

      it 'sync on result does not call wait on resolved promises' do
        p1 = Class.new(Promise) do
          def wait
            raise 'wait not expected'
          end
        end.resolve(:one)
        p2 = DelayedPromise.new
        DelayedPromise.deferred << -> { p2.fulfill(:two) }

        result = Promise.all([p1, p2])

        expect(result.sync).to eq([:one, :two])
      end
    end

    describe '.map_value' do
      it "yields the argument directly if it isn't a promise" do
        p = Promise.map_value(2) { |v| v + 1 }
        expect(p).to eq(3)
      end

      it 'uses .then on a promise argument using the given block' do
        p = Promise.map_value(Promise.resolve(2)) { |v| v + 1 }
        expect(p.sync).to eq(3)
      end

      it 'uses .then on a promise argument of another class' do
        p1 = Class.new(Promise).resolve(2)
        p2 = DelayedPromise.map_value(p1) { |v| v + 1 }
        expect(p2.sync).to eq(3)
      end
    end
  end
end
