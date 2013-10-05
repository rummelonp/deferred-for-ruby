# -*- coding: utf-8 -*-

require 'spec_helper'

describe Deferred::Callbacks do
  let(:callbacks) { Deferred::Callbacks.new }

  shared_examples 'callbacks' do
    let(:output) { 'x' }

    def add_to_output(string)
      Proc.new { output << string }
    end

    def output_a
      @output_a ||= add_to_output('a')
    end

    def output_b
      @output_b ||= add_to_output('b')
    end

    def output_c
      @output_c ||= add_to_output('c')
    end

    context 'basic binding and firing' do
      before do
        callbacks.add { |string| output << string }
        callbacks.fire('a')
      end

      it 'basic binding and firing' do
        expect(output).to eq 'xa'
      end

      it '#fired? detects firing' do
        expect(callbacks.fired?).to be true
      end
    end

    context 'adding a callback after disabling' do
      before do
        callbacks.disable!
        callbacks.add { |string| output << string }
      end

      it 'adding a callback after disabling' do
        expect(output).to eq 'x'
      end

      it 'firing after disabling' do
        callbacks.fire('a')
        expect(output).to eq 'x'
      end
    end

    it 'emptying while firing' do
      callbacks.add(callbacks.method(:empty!))
      handler = Proc.new { raise 'not emptied' }
      expect(handler).to_not receive(:call)
      callbacks.add(handler)
      callbacks.fire
    end

    it 'disabling while firing' do
      callbacks.add(callbacks.method(:disable!))
      handler = Proc.new { raise 'not disabled' }
      expect(handler).to_not receive(:call)
      callbacks.add(handler)
      callbacks.fire
    end

    it 'basic binding, removing and firing' do
      callbacks.add(output_a, output_b, output_c)
      callbacks.remove(output_b, output_c)
      callbacks.fire
      expect(output).to eq 'xa'
    end

    it 'empty' do
      callbacks.add(output_a)
      callbacks.add(output_b)
      callbacks.add(output_c)
      callbacks.empty!
      callbacks.fire
      expect(output).to eq 'x'
    end

    it 'lock early' do
      callbacks.add { |string| output << string }
      callbacks.lock!
      callbacks.add { |string| output << string }
      callbacks.fire('a')
      callbacks.add { |string| output << string }
      expect(output).to eq 'x'
    end

    it 'proper ordering' do
      callbacks.add(Proc.new {
          callbacks.add(output_c)
          output_a.call
        }, output_b)
      callbacks.fire
      expect(output).to eq results[:ordering]
    end

    it 'fire in firing' do
      callbacks.add { |string| output << string }
      callback = Proc.new {
        callbacks.remove(callback)
        callbacks.fire('b')
      }
      callbacks.add(callback)
      callbacks.fire('a')
      expect(output).to eq results[:fire_in_firing]
    end

    context 'add and fire again' do
      before do
        callbacks.add(Proc.new {
            callbacks.add(output_c)
            output_a.call
          }, output_b)
        callbacks.fire
        output.replace('x')
        callbacks.add(Proc.new {
            callbacks.add(output_c)
            output_a.call
          }, output_b)
      end

      it 'add after fire' do
        expect(output).to eq results[:add_after_fire]
      end

      it 'fire again' do
        output.replace('x')
        callbacks.fire
        expect(output).to eq results[:fire_again]
      end
    end

    context 'multiple fire' do
      before do
        callbacks.add { |string| output << string }
        callbacks.fire('a')
      end

      it 'multiple fire (first fire)' do
        expect(output).to eq 'xa'
      end

      it 'multiple fire (first new callback)' do
        output.replace('x')
        callbacks.add { |string| output << string }
        expect(output).to eq results[:multiple_fire_first_new_callback]
      end

      it 'multiple fire (second fire)' do
        output.replace('x')
        callbacks.add { |string| output << string }
        output.replace('x')
        callbacks.fire('b')
        expect(output).to eq results[:multiple_fire_second_fire]
      end

      it 'multiple fire (second new callback)' do
        output.replace('x')
        callbacks.add { |string| output << string }
        output.replace('x')
        callbacks.fire('b')
        output.replace('x')
        callbacks.add { |string| output << string }
        expect(output).to eq results[:multiple_fire_second_new_callback]
      end
    end

    it 'callback returning false' do
      callbacks.add(output_a, Proc.new { false }, output_b)
      callbacks.add(output_a)
      callbacks.fire
      expect(output).to eq results[:return_false]
    end

    it 'adding a callback after one returned false' do
      callbacks.add(output_a, Proc.new { false }, output_b)
      callbacks.add(output_a)
      callbacks.fire
      output.replace('x')
      callbacks.add(output_c)
      expect(output).to eq results[:add_another_callback_after_return_false]
    end

    it 'no callback iteration' do
      output.replace('')
      handler = Proc.new { output << 'x' }
      callbacks.add(handler)
      callbacks.add(handler)
      callbacks.fire
      expect(output).to eq results[:no_callback_iteration]
    end
  end

  describe '.new' do
    let(:callbacks) { Deferred::Callbacks.new(options) }

    context 'with {}' do
      let(:options) { {} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'x',
          fire_again: 'xabcabcc',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xaba',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {once: true}' do
      let(:options) { {once: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xa',
          add_after_fire: 'x',
          fire_again: 'x',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'x',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xaba',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {memory: true}' do
      let(:options) { {memory: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'xabc',
          fire_again: 'xabcabccc',
          multiple_fire_first_new_callback: 'xa',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'xb',
          return_false: 'xaba',
          add_another_callback_after_return_false: 'xc',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {unique: true}' do
      let(:options) { {unique: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'x',
          fire_again: 'xabca',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xab',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'x',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {stop_on_false: true}' do
      let(:options) { {stop_on_false: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'x',
          fire_again: 'xabcabcc',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xa',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {once: true, memory: true}' do
      let(:options) { {once: true, memory: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xa',
          add_after_fire: 'xabc',
          fire_again: 'x',
          multiple_fire_first_new_callback: 'xa',
          multiple_fire_second_fire: 'x',
          multiple_fire_second_new_callback: 'xa',
          return_false: 'xaba',
          add_another_callback_after_return_false: 'xc',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {once: true, unique: true}' do
      let(:options) { {once: true, unique: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xa',
          add_after_fire: 'x',
          fire_again: 'x',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'x',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xab',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'x',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {once: true, stop_on_false: true}' do
      let(:options) { {once: true, stop_on_false: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xa',
          add_after_fire: 'x',
          fire_again: 'x',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'x',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xa',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {memory: true, unique: true}' do
      let(:options) { {memory: true, unique: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'xa',
          fire_again: 'xabca',
          multiple_fire_first_new_callback: 'xa',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'xb',
          return_false: 'xab',
          add_another_callback_after_return_false: 'xc',
          no_callback_iteration: 'x',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {memory: true, stop_on_false: true}' do
      let(:options) { {memory: true, stop_on_false: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'xabc',
          fire_again: 'xabcabccc',
          multiple_fire_first_new_callback: 'xa',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'xb',
          return_false: 'xa',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'xx',
        }
      end
      include_examples 'callbacks'
    end

    context 'with {unique: true, stop_on_false: true}' do
      let(:options) { {unique: true, stop_on_false: true} }
      let(:results) do
        {
          ordering: 'xabc',
          fire_in_firing: 'xab',
          add_after_fire: 'x',
          fire_again: 'xabca',
          multiple_fire_first_new_callback: 'x',
          multiple_fire_second_fire: 'xbb',
          multiple_fire_second_new_callback: 'x',
          return_false: 'xa',
          add_another_callback_after_return_false: 'x',
          no_callback_iteration: 'x',
        }
      end
      include_examples 'callbacks'
    end

    it 'options are copied' do
      options = {unique: true}
      callbacks = Deferred::Callbacks.new(options)
      count = 0
      handler = Proc.new do
        raise 'called once' if count > 0
        count += 1
      end
      expect(handler).to receive(:call).once
      options[:unique] = false
      callbacks.add(handler, handler)
      callbacks.fire
    end
  end

  describe '#fire' do
    it 'arguments are copied internally' do
      callbacks = Deferred::Callbacks.new(memory: true)
      args = ['hello']
      callbacks.fire(*args)
      args[0] = 'world'
      handler = Proc.new do |hello|
        expect(hello).to eq 'hello'
      end
      expect(handler).to receive(:call).once
      callbacks.add(handler)
    end
  end

  describe '#add' do
    it "adding a string doesn't cause a stack overflow" do
      expect { callbacks.add('hello world') }.to_not raise_error
    end

    it 'can add callbacks by array or block' do
      handler1 = Proc.new { }
      handler2 = Proc.new { }
      handler3 = Proc.new { }
      expect(handler1).to receive(:call)
      expect(handler2).to receive(:call)
      expect(handler3).to receive(:call)
      callbacks.add([handler1, handler2], &handler3).fire
    end
  end

  describe '#remove' do
    it 'should remove all instances' do
      handler1 = Proc.new { raise "callback wasn't removed" }
      handler2 = Proc.new { }
      expect(handler1).to_not receive(:call)
      expect(handler2).to receive(:call).once
      callbacks.add(handler1, handler1, handler2).remove(handler1).fire
    end

    it 'can remove callbacks by array or block' do
      handler1 = Proc.new { }
      handler2 = Proc.new { }
      handler3 = Proc.new { }
      expect(handler1).to_not receive(:call)
      expect(handler2).to_not receive(:call)
      expect(handler3).to_not receive(:call)
      callbacks.add(handler1, handler2, handler3)
      callbacks.remove([handler1, handler2], &handler3).fire
    end
  end

  describe '#has?' do
    def get_a
      @get_a ||= Proc.new { 'a' }
    end

    def get_b
      @get_b ||= Proc.new { 'b' }
    end

    def get_c
      @get_c ||= Proc.new { 'c' }
    end

    before do
      callbacks.add(get_a, get_b, get_c)
    end

    context 'normal list' do
      it 'no arguments to .has? returns whether callback(s) are attached or not' do
        expect(callbacks.has?).to be true
      end

      it 'check if a specific callback is in the callbacks list' do
        expect(callbacks.has?(get_a)).to be true
      end

      it 'remove a specific callback and make sure its no longer there' do
        callbacks.remove(get_b)
        expect(callbacks.has?(get_b)).to be false
      end

      it 'remove a specific callback and make sure other callback is still there' do
        callbacks.remove(get_b)
        expect(callbacks.has?(get_a)).to be true
      end

      it 'empty list and make sure there are no callback(s)' do
        callbacks.empty!
        expect(callbacks.has?).to be false
      end

      it 'check for a specific callback in an empty! list' do
        callbacks.empty!
        expect(callbacks.has?(get_a)).to be false
      end

      it 'check if list has callback(s) from within a callback' do
        handler = Proc.new do
          expect(callbacks.has?).to be_true
        end
        expect(handler).to receive(:call)
        callbacks.add(get_a, get_b, handler).fire
      end

      it 'check if list has a specific callback from within a callback' do
        handler = Proc.new do
          expect(callbacks.has?(get_a)).to be_true
        end
        expect(handler).to receive(:call)
        callbacks.add(get_a, get_b, handler).fire
      end

      it 'callbacks list has callback(s) after firing' do
        callbacks.add(get_a, get_b).fire
        expect(callbacks.has?).to be true
      end

      it 'disabled list has no callbacks (returns false)' do
        callbacks.disable!
        expect(callbacks.has?).to be false
      end

      it 'check for a specific callback in a disabled list' do
        callbacks.disable!
        expect(callbacks.has?(get_a)).to be false
      end
    end

    context 'unique list' do
      let(:callbacks) { Deferred::Callbacks.new(unique: true) }

      before do
        callbacks.add(get_a)
        callbacks.add(get_a)
      end

      it 'check if unique list has callback(s) attached' do
        expect(callbacks.has?).to be true
      end

      it 'locked list is empty and returns false' do
        callbacks.lock!
        expect(callbacks.has?).to be false
      end
    end
  end

  describe '#disabled?' do
    it 'return false after creation' do
      expect(callbacks.disabled?).to be false
    end

    it 'disabled list return true' do
      callbacks.disable!
      expect(callbacks.disabled?).to be true
    end
  end

  describe '#locked?' do
    it 'return false after creation' do
      expect(callbacks.locked?).to be false
    end

    it 'locked list return true' do
      callbacks.lock!
      expect(callbacks.locked?).to be true
    end
  end
end
