# -*- coding: utf-8 -*-

require 'spec_helper'

describe Deferred::Promise do
  let(:deferred) { Deferred.new }
  let(:promise) { deferred.promise }

  describe '#promise' do
    it 'should return self' do
      expect(promise.promise).to eq promise
    end
  end

  shared_examples 'delegate' do
    it 'delegate to deferred' do
      handler = Proc.new { }
      expect(deferred).to receive(listner)
      deferred.promise.send(listner, handler)
    end
  end

  shared_examples 'chainable' do
    it 'is chainable' do
      expect(promise.send(listner)).to eq promise
    end
  end

  [:done, :fail, :progress, :always].each do |listner|
    describe "##{listner}" do
      let(:listner) { listner }
      include_examples 'delegate'
      include_examples 'chainable'
    end
  end

  [:state, :then, :pipe].each do |listner|
    describe "##{listner}" do
      let(:listner) { listner }
      include_examples 'delegate'
    end
  end
end
