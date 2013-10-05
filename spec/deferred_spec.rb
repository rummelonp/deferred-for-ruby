# -*- coding: utf-8 -*-

require 'spec_helper'

describe Deferred do
  let(:deferred) { Deferred.new }

  describe '.new' do
    it 'passed block executed' do
      handler = Proc.new do |value|
        expect(value).to eq 'done'
      end
      expect(handler).to receive(:call).and_call_original
      Deferred.new { |defer|
        defer.resolve('done')
      }.done(handler)
    end
  end

  describe '#state' do
    it 'pending after creation' do
      expect(deferred.state).to eq Deferred::PENDING
    end

    it 'pending after notification' do
      deferred.progress { }
      deferred.notify 0
      expect(deferred.state).to eq Deferred::PENDING
    end

    it 'not pending after resolve' do
      deferred.resolve
      expect(deferred.state).to_not eq Deferred::PENDING
    end

    it 'not pending after reject' do
      deferred.reject
      expect(deferred.state).to_not eq Deferred::PENDING
    end
  end

  context '#resolve' do
    before do
      deferred.resolve
    end

    it 'should resolved' do
      expect(deferred.resolved?).to be true
    end

    it 'should call done callbacks' do
      handler = Proc.new do
        expect(deferred.state).to eq Deferred::RESOLVED
      end
      expect(handler).to receive(:call).and_call_original
      deferred.done(handler)
    end

    it 'should not call fail callbacks' do
      handler = Proc.new { raise }
      expect(handler).to_not receive(:call)
      deferred.fail(handler)
    end

    it 'should call always callbacks' do
      handler = Proc.new { }
      expect(handler).to receive(:call)
      deferred.always(handler)
    end
  end

  context '#reject' do
    before do
      deferred.reject
    end

    it 'should rejected' do
      expect(deferred.rejected?).to be true
    end

    it 'should not call done callbacks' do
      handler = Proc.new { raise }
      expect(handler).to_not receive(:call)
      deferred.done(handler)
    end

    it 'should call fail callbacks' do
      handler = Proc.new do
        expect(deferred.state).to eq Deferred::REJECTED
      end
      expect(handler).to receive(:call).and_call_original
      deferred.fail(handler)
    end

    it 'should call always callbacks' do
      handler = Proc.new { }
      expect(handler).to receive(:call)
      deferred.always(handler)
    end
  end

  describe '#progress' do
    it 'right value received' do
      checked = 0
      handler = Proc.new do |value|
        expect(value).to eq checked
      end
      expect(handler).to receive(:call).exactly(3).times.and_call_original
      deferred.progress(handler)
      while checked < 3
        deferred.notify(checked)
        checked += 1
      end
    end
  end

  describe '#then' do
    shared_examples 'values' do
      it 'first resolve value' do
        expect(@value1).to eq 2
      end

      it 'second resolve value' do
        expect(@value2).to eq 3
      end

      it 'result of filter' do
        expect(@value3).to eq 6
      end
    end

    context 'filtering (done)' do
      it_behaves_like 'values' do
        before do
          deferred.done { |a, b| @value1, @value2 = a, b }
            .then { |a, b| a * b }
            .done { |result| @value3 = result }
          deferred.resolve(2, 3)
        end
      end

      it 'then should not be called on reject' do
        handler = Proc.new { }
        expect(handler).to_not receive(:call)
        deferred.reject.then(handler)
      end

      it 'then done callback can return nil' do
        handler1 = Proc.new { }
        expect(handler1).to receive(:call)
        handler2 = Proc.new do |value|
          expect(value).to be nil
        end
        expect(handler2).to receive(:call).and_call_original
        deferred.resolve.then(handler1).done(handler2)
      end
    end

    context 'filtering (fail)' do
      it_behaves_like 'values' do
        before do
          deferred.fail { |a, b| @value1, @value2 = a, b }
            .then(nil, Proc.new { |a, b| a * b })
            .fail { |result| @value3 = result }
          deferred.reject(2, 3)
        end
      end

      it 'then should not be called on reject' do
        handler = Proc.new { }
        expect(handler).to_not receive(:call)
        deferred.resolve.then(nil, handler)
      end

      it 'then done callback can return nil' do
        handler1 = Proc.new { }
        expect(handler1).to receive(:call)
        handler2 = Proc.new do |value|
          expect(value).to be nil
        end
        expect(handler2).to receive(:call).and_call_original
        deferred.reject.then(nil, handler1).fail(handler2)
      end
    end

    context 'filtering (progress)' do
      it_behaves_like 'values' do
        before do
          deferred.progress { |a, b| @value1, @value2 = a, b }
            .then(nil, nil, Proc.new { |a, b| a * b })
            .progress { |result| @value3 = result }
          deferred.notify(2, 3)
        end
      end
    end

    context 'deferred (done)' do
      it_behaves_like 'values' do
        before do
          deferred.done { |a, b| @value1, @value2 = a, b }
            .then { |a, b| Deferred.new { |d| d.reject(a * b) } }
            .fail { |result| @value3 = result }
          deferred.resolve(2, 3)
        end
      end
    end

    context 'deferred (fail)' do
      it_behaves_like 'values' do
        before do
          deferred.fail { |a, b| @value1, @value2 = a, b }
            .then(nil, Proc.new { |a, b| Deferred.new { |d| d.resolve(a * b) } })
            .done { |result| @value3 = result }
          deferred.reject(2, 3)
        end
      end
    end

    context 'deferred (progress)' do
      it_behaves_like 'values' do
        before do
          deferred.progress { |a, b| @value1, @value2 = a, b }
            .then(nil, nil, Proc.new { |a, b| Deferred.new { |d| d.resolve(a * b) } })
            .done { |result| @value3 = result }
          deferred.notify(2, 3)
        end
      end
    end
  end

  describe '.when' do
    context 'test some triggers the creation of a new promise' do
      shared_examples 'resolve with' do |message|
        it "test the promise was resolve with #{message}" do
          handler = Proc.new do |resolve_value|
            expect(resolve_value).to eq value
          end
          expect(handler).to receive(:call).and_call_original
          promise = Deferred.when(value).done(handler)
          expect(promise).to be_is_a Deferred::Promise
        end
      end

      include_examples 'resolve with', 'an empty string' do
        let(:value) { '' }
      end

      include_examples 'resolve with', 'a non-empty string' do
        let(:value) { 'some string' }
      end

      include_examples 'resolve with', 'zero' do
        let(:value) { 0 }
      end

      include_examples 'resolve with', 'a number other than zero' do
        let(:value) { 1 }
      end

      include_examples 'resolve with', 'true' do
        let(:value) { true }
      end

      include_examples 'resolve with', 'false' do
        let(:value) { false }
      end

      include_examples 'resolve with', 'nil' do
        let(:value) { nil }
      end

      include_examples 'resolve with', 'a plain hash' do
        let(:value) { {} }
      end

      include_examples 'resolve with', 'an array' do
        let(:value) { [1, 2, 3] }
      end
    end

    context 'test calling when with no parameter triggers the creation of a new promise' do
      it 'test the promise was resolved with no parameter' do
        handler = Proc.new do |resolve_value|
          expect(resolve_value).to eq nil
        end
        expect(handler).to receive(:call).and_call_original
        promise = Deferred.when.done(handler)
        expect(promise).to be_is_a Deferred::Promise
      end
    end

    it 'callback executed exactly' do
      cache = nil
      (1..3).each do |count|
        subordinate = Deferred.new.resolve(count)
        handler = Proc.new do |value|
          expect(value).to eq 1
          cache = value
        end
        expect(handler).to receive(:call).once.and_call_original
        Deferred.when(cache || subordinate).done(handler)
      end
    end

    context 'joined' do
      shared_examples 'should resolve' do
        it 'should resolve' do
          handler = Proc.new do |a, b|
            expect([a, b]).to eq expected
          end
          expect(handler).to receive(:call).and_call_original
          Deferred.when(first_deferred, second_deferred).done(handler)
        end
      end

      shared_examples 'should not resolve' do
        it 'should not resolve' do
          handler = Proc.new { |a, b| }
          expect(handler).to_not receive(:call)
          Deferred.when(first_deferred, second_deferred).done(handler)
        end
      end

      shared_examples 'should reject' do
        it 'should reject' do
          handler = Proc.new do |a, b|
            expect([a, b]).to eq expected
          end
          expect(handler).to receive(:call).and_call_original
          Deferred.when(first_deferred, second_deferred).fail(handler)
        end
      end

      shared_examples 'should not reject' do
        it 'should not reject' do
          handler = Proc.new { |a, b| }
          expect(handler).to_not receive(:call)
          Deferred.when(first_deferred, second_deferred).fail(handler)
        end
      end

      shared_examples 'should notify' do
        it 'should notify' do
          handler = Proc.new do |a, b|
            expect([a, b]).to eq expected_notify
          end
          expect(handler).to receive(:call).and_call_original
          Deferred.when(first_deferred, second_deferred).progress(handler)
        end
      end

      shared_examples 'should not notify' do
        it 'should not notify' do
          handler = Proc.new { |a, b| }
          expect(handler).to_not receive(:call)
          Deferred.when(first_deferred, second_deferred).progress(handler)
        end
      end

      deferreds = {
        value: {
          create_deferred: Proc.new { 1 },
          will_succeed: true,
        },
        success: {
          create_deferred: Proc.new { Deferred.new.resolve(1) },
          will_succeed: true,
        },
        error: {
          create_deferred: Proc.new { Deferred.new.reject(0) },
          will_error: true,
        },
        notify: {
          create_deferred: Proc.new { Deferred.new.notify(true) },
          will_notify: true,
        },
        future_success: {
          create_deferred: Proc.new { Deferred.new.notify(true) },
          after: Proc.new { |d| d.resolve(1) },
          will_succeed: true,
          will_notify: true,
        },
        future_error: {
          create_deferred: Proc.new { Deferred.new.notify(true) },
          after: Proc.new { |d| d.reject(0) },
          will_error: true,
          will_notify: true,
        },
      }

      deferreds.each_pair do |first_key, first|
        deferreds.each_pair do |second_key, second|
          context "join #{first_key} / #{second_key}" do
            let(:first_deferred) { first[:create_deferred].call }
            let(:second_deferred) { second[:create_deferred].call }

            after do
              first[:after].call(first_deferred)   if first[:after]
              second[:after].call(second_deferred) if second[:after]
            end

            if first[:will_succeed] && second[:will_succeed]
              let(:expected) { [1, 1] }
              include_examples 'should resolve'
            else
              let(:expected) { [0, nil] }
              include_examples 'should not resolve'
            end

            if first[:will_error] || second[:will_error]
              include_examples 'should reject'
            else
              include_examples 'should not reject'
            end

            if (first[:will_notify] || second[:will_notify]) &&
                (!first[:will_error] || first[:will_notify])
              let(:expected_notify) { [first[:will_notify], second[:will_notify]] }
              include_examples 'should notify'
            else
              include_examples 'should not notify'
            end
          end
        end
      end
    end
  end

  context 'chainability' do
    shared_examples 'chainable' do
      it 'is chanable' do
        expect(deferred.send(listner)).to eq deferred
      end
    end

    [:done, :fail, :progress, :always].each do |listner|
      describe "##{listner}" do
        let(:listner) { listner }
        include_examples 'chainable'
      end
    end
  end
end
