# -*- coding: utf-8 -*-

class Deferred
  class Promise
    # @param deferred [Deferred]
    def initialize(deferred)
      deferred
      [:done, :fail, :progress, :always].each do |action|
        define_singleton_method(action) do |*args, &block|
          deferred.send(action, *args, &block)
          self
        end
      end
      [:state, :then, :pipe].each do |action|
        define_singleton_method(action) do |*args, &block|
          deferred.send(action, *args, &block)
        end
      end
    end

    # Returns the self
    # @return [Promise] self
    def promise
      self
    end

    # @method state
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#state
    # @return [Symbol]

    # @method done(*args, &block)
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#done
    # @return [Promise] self

    # @method fail(*args, &block)
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#fail
    # @return [Promise] self

    # @method progress(*args, &block)
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#progress
    # @return [Promise] self

    # @method always(*args, &block)
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#always
    # @return [Promise] self

    # @method then(*args, &block)
    #
    # Delegate to {Deferred}
    #
    # @see Deferred#then
    # @return [Promise] Promise of new deferred
  end
end
