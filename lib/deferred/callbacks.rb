# -*- coding: utf-8 -*-

class Deferred
  # A multi-purpose callbacks list object that provides a powerful way to manage
  # callback lists.
  class Callbacks
    DEFAULT_OPTIONS = {
      once: false,
      memory: false,
      unique: false,
      stop_on_false: false,
    }.freeze

    # Create a callback list.
    # By default a callback list will act like an event callback list and can be
    # "fired" multiple times.
    #
    # @param options [Hash]
    # @option options [Boolean] :once (false)
    #   will ensure the callback list can only be fired once
    # @option options [Boolean] :memory (false)
    #   will keep track of previous values and will call any callback added
    #   after the list has been fired right away with the latest "memorized"
    #   values
    # @option options [Boolean] :unique (false)
    #   will ensure a callback can only be added once (no duplicate in the list)
    # @option options [Boolean] :stop_on_false (false)
    #   interrupt callings when a callback returns false
    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge(options)
      # Last fire value (for non-forgettable lists)
      @memory = nil
      # Flag to know if list was already fired
      @fired = false
      # Flag to know if list is currently firing
      @firing = false
      # First callback to fire (used internally by add and fireWith)
      @firing_start = 0
      # End of the loop when firing
      @firing_length = 0
      # Index of currently firing callback (modified by remove if needed)
      @firing_index = 0
      # Actual callback list
      @list = []
      # Stack of fire calls for repeatable lists
      @stack = options[:once] ? nil : []
    end

    # Call all of the callbacks with the given arguments
    #
    # @overload fire(*arguments)
    #   @param arguments [Array<Object>]
    #     the argument or list of arguments to pass back to the callback list
    # @return [Callbacks] self
    def fire(*args)
      return self unless @list && (!fired? || @stack)
      _fire(*args)
    end

    # Determine if the callbacks have already been called at least once
    #
    # @return [Boolean]
    def fired?
      @fired
    end

    # Add a callback or a collection of callbacks to a callback list
    #
    # @overload add(*callbacks)
    #   @param callbacks [Array<Proc, Method>] array of callbacks
    # @overload add
    #   @yield [*arguments]
    # @return [Callbacks] self
    def add(*args, &block)
      return self unless @list
      # First, we save the current length
      start = @list.size
      args << block if block_given?
      args.flatten.each do |arg|
        case arg
        when Proc, Method
          @list << arg unless @options[:unique] && has?(arg)
        end
      end
      # Do we need to add the callbacks to the current firing batch?
      if @firing
        @firing_length = @list.size
        # With memory, if we're not firing then we should call right away
      elsif @memory
        @firing_start = start
        _fire(*@memory)
      end
      self
    end

    # Remove a callback or a collection of callbacks from a callback list
    #
    # @overload remove(*callbacks)
    #   @param callbacks [Array<Proc, Method>] array of callbacks
    # @return [Callbacks] self
    def remove(*args, &block)
      return self unless @list
      args << block if block_given?
      args.flatten.each do |arg|
        case arg
        when Proc, Method
          while index = @list.index(arg)
            @list.delete_at(index)
            next unless @firing
            @firing_length -= 1 if index <= @firing_length
            @firing_index  -= 1 if index <= @firing_index
          end
        end
      end
      self
    end

    # Determine whether a supplied callback is in a list
    #
    # @overload has?(callback)
    # @return [Boolean]
    def has?(arg = nil)
      !!(arg ? @list && @list.include?(arg) : @list && @list.any?)
    end

    # Remove all of the callbacks from a list
    #
    # @return [Callbacks] self
    def empty!
      @list = []
      @firing_length = 0
      self
    end

    # Disable a callback list from doing anything more
    #
    # @return [Callbacks] self
    def disable!
      @list = @stack = @memory = nil
      self
    end

    # Determine if the callbacks list has been disabled
    #
    # @return [Boolean]
    def disabled?
      @list.nil?
    end

    # Lock a callback list in its current state
    #
    # @return [Callbacks] self
    def lock!
      @stack = nil
      disable! unless @memory
      self
    end

    # Determine if the callbacks list has been locked
    #
    # @return [Boolean]
    def locked?
      @stack.nil?
    end

    private

    def _fire(*args)
      if @firing
        @stack.push(args)
      else
        @memory = @options[:memory] ? args : nil
        @fired = true
        @firing_index = @firing_start
        @firing_start = 0
        @firing_length = @list.size
        @firing = true
        while @list && @firing_index < @firing_length
          callback = @list[@firing_index]
          result = (
            case arity = callback.arity
            when -1
              callback.call(*args)
            else
              callback.call(*args.slice(0, arity))
            end
          )
          if @options[:stop_on_false] && result == false
            # To prevent further calls using add
            @memory = false
            break
          end
          @firing_index += 1
        end
        @firing = false
        if @list
          if @stack
            _fire(*@stack.shift) if @stack.any?
          elsif @memory
            @list = []
          else
            disable!
          end
        end
      end
      self
    end
  end
end
