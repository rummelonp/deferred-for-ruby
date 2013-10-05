# -*- coding: utf-8 -*-

require 'deferred/callbacks'
require 'deferred/promise'
require 'deferred/version'

# A chainable utility object with methods to register multiple callbacks into
# callback queues, invoke callback queues, and relay the success or failure
# state of any synchronous or asynchronous function
class Deferred
  STATES = [
    PENDING  = :pending,
    RESOLVED = :resolved,
    REJECTED = :rejected,
  ].freeze

  # @yield [deffered] a call that is called just before the constructor returns
  def initialize(&block)
    @state = PENDING

    @resolve_list = Callbacks.new(once: true, memory: true)
    @reject_list  = Callbacks.new(once: true, memory: true)
    @notify_list  = Callbacks.new(memory: true)

    # Handle state
    @resolve_list.add(
      Proc.new{ @state = RESOLVED },
      @reject_list.method(:disable!),
      @notify_list.method(:lock!),
    )
    @reject_list.add(
      Proc.new{ @state = REJECTED },
      @resolve_list.method(:disable!),
      @notify_list.method(:lock!),
    )

    yield self if block_given?
  end

  # @return [Promise]
  def promise
    @promise ||= Deferred::Promise.new(self)
  end

  # Determine the current state
  #
  # @return [Symbol]
  attr_reader :state

  # Determine whether has been resolved
  #
  # @return [Boolean]
  def resolved?
    state == RESOLVED
  end

  # Determine whether has been rejected
  #
  # @return [Boolean]
  def rejected?
    state == REJECTED
  end

  # Resolve a deferred and call any done callbacks with the given args
  #
  # @overload resolve(*arguments)
  #   @param arguments [Array<Object>]
  #     optional arguments that are passed to the done callbacks
  # @return [Deferred] self
  def resolve(*args)
    @resolve_list.fire(*args)
    self
  end

  # Reject a deferred and call any fail callbacks with the given args
  #
  # @overload reject(*arguments)
  #   @param arguments [Array<Object>]
  #     optional arguments that are passed to the fail callbacks
  # @return [Deferred] self
  def reject(*args)
    @reject_list.fire(*args)
    self
  end

  # Call the progress callbacks with the given args
  #
  # @overload notify(*arguments)
  #   @param arguments [Array<Object>]
  #     optional arguments that are passed to the progress callbacks
  # @return [Deferred] self
  def notify(*args)
    @notify_list.fire(*args)
    self
  end

  # Add handlers to be called when resolved
  #
  # @overload done(*callbacks)
  #   @param callbacks [Array<Proc, Method>] array of callbacks
  # @overload done
  #   @yield [*arguments]
  # @return [Deferred] self
  def done(*args, &block)
    args << block if block_given?
    @resolve_list.add(*args)
    self
  end

  # Add handlers to be called when rejected
  #
  # @overload fail(*callbacks)
  #   @param callbacks [Array<Proc, Method>] array of callbacks
  # @overload fail
  #   @yield [*arguments]
  # @return [Deferred] self
  def fail(*args, &block)
    args << block if block_given?
    @reject_list.add(*args)
    self
  end

  # Add handlers to be called when generates progress notifications
  #
  # @overload progress(*callbacks)
  #   @param callbacks [Array<Proc, Method>] array of callbacks
  # @overload progress
  #   @yield [*arguments]
  # @return [Deferred] self
  def progress(*args, &block)
    args << block if block_given?
    @notify_list.add(*args)
    self
  end

  # Add handlers to be called when either resolved or rejected
  #
  # @overload always(*callbacks)
  #   @param callbacks [Array<Proc, Method>] array of callbacks
  # @overload always
  #   @yield [*arguments]
  # @return [Deferred] self
  def always(*args, &block)
    args << block if block_given?
    done(*args).fail(*args)
    self
  end

  # Add handlers to be called when resolved, rejected, or still in progress
  #
  # @overload then(done_filter)
  #   @param done_filter [Proc, Method, Array]
  #     a callback that is called when resolved
  # @overload then(done_filter, fail_filter)
  #   @param done_filter [Proc, Method, Array]
  #     a callback that is called when resolved
  #   @param fail_filter [Proc, Method, Array]
  #     a callback that is called when rejected
  # @overload then(done_filter, fail_filter, progress_filter)
  #   @param done_filter [Proc, Method, Array]
  #     a callback that is called when resolved
  #   @param fail_filter [Proc, Method, Array]
  #     a callback that is called when rejected
  #   @param progress_filter [Proc, Method, Array]
  #     an optional callback that is called when progress notifications
  # @return [Deferred] self
  def then(*callbacks, &block)
    callbacks << block if block_given?
    self.class.new { |new_defer|
      # Forwarding actions to new defer
      [:done, :fail, :progress].zip(
        callbacks,
        [:resolve, :reject, :notify],
      ).each do |(listner, callback, action)|
        send(listner) do |*args|
          returned = callback ? callback.call(*args) : nil
          if returned.respond_to?(:promise)
            returned.promise
              .done(new_defer.method(:resolve))
              .fail(new_defer.method(:reject))
              .progress(new_defer.method(:notify))
          else
            new_defer.send(action, *(callback ? [returned] : args))
          end
        end
      end
    }.promise
  end

  # Provides a way to execute callback based on one or more objects,
  # usually Deferred objects that represent asynchronous events
  #
  # @overload when(deferred)
  #   @param deferred [Deferred, Object]
  # @overload when(*deferreds)
  #   @param deferred [Array<Deferred, Object>]
  # @return [Promise]
  def self.when(*subordinates)
    resolve_values = subordinates
    length = resolve_values.size
    # The count of uncompleted subordinates
    remaining = length != 1 || subordinates.first.respond_to?(:promise) ? length : 0
    # The master Deferred. If subordinates consist of only a single Deferred, just use that.
    deferred = remaining == 1 ? subordinates.first : new
    # Add listeners to Deferred subordinates; treat others as resolved
    if remaining > 1
      progress_values = Array.new(length)
      # Update function for both resolve and progress values
      create_update = Proc.new do |i, values|
        Proc.new do |value|
          values[i] = value
          if values.equal?(progress_values)
            deferred.notify(*values)
          elsif (remaining -= 1) == 0
            deferred.resolve(*values)
          end
        end
      end
      resolve_values.each.with_index do |value, index|
        if value.respond_to?(:promise)
          value.promise
            .done(create_update.call(index, resolve_values))
            .fail(deferred.method(:reject))
            .progress(create_update.call(index, progress_values))
        else
          remaining -= 1
        end
      end
    end
    # If we're not waiting on anything, resolve the master
    if remaining == 0
      deferred.resolve(*resolve_values)
    end
    deferred.promise
  end
end
