# frozen_string_literal: true

module Polyphony
  # Implements a limited resource pool
  class ResourcePool
    attr_reader :limit, :size

    # Initializes a new resource pool. The given block is used for creating a
    # resource:
    #
    #   ResourcePool.new { Sequel.connect(DB_URL) }
    #
    # @param limit [Integer] maximum open resources
    def initialize(limit: 4, &block)
      @allocator = block
      @limit = limit
      @size = 0
      @stock = Polyphony::Queue.new
      @acquired_resources = {}
    end

    # Returns number of currently available resources.
    #
    # @return [Integer] size of resource stock
    def available
      @stock.size
    end

    # Acquires a resource, passing it to the given block. If no resource is
    # available, blocks until a resource becomes available. After the block has
    # run, the resource is released back to the pool. The resource is passed to
    # the block as its only argument.
    #
    # This method is re-entrant: if called from the same fiber, it will immediately
    # return the resource currently acquired by the fiber.
    #
    #   rows = db_pool.acquire do |db|
    #     db.query(sql).to_a
    #   end
    #
    # @return [any] return value of block
    def acquire(&block)
      fiber = Fiber.current
      return yield @acquired_resources[fiber] if @acquired_resources[fiber]

      acquire_from_stock(fiber, &block)
    end

    # Acquires a resource, proxies the method calls to the resource, then
    # releases it. Methods can also be called with blocks, as in the following
    # example:
    #
    #   db_pool.query(sql) { |result|
    #     process_result_rows(result)
    #   }
    #
    # @param sym [Symbol] method name
    # @param args [Array<any>] method arguments
    # @param kwargs [Hash] keyword arguments
    # @return [any] result of method call
    def method_missing(sym, *args, **kwargs, &block)
      acquire { |r| r.send(sym, *args, **kwargs, &block) }
    end

    # @!visibility private
    def respond_to_missing?(*_args)
      true
    end

    # Discards the currently-acquired resource
    # instead of returning it to the pool when done.
    #
    # @return [Polyphony::ResourcePool] self
    def discard!
      @size -= 1 if @acquired_resources.delete(Fiber.current)
      self
    end

    # Fills the pool to capacity.
    #
    # @return [Polyphony::ResourcePool] self
    def fill!
      add_to_stock while @size < @limit
      self
    end

    private

    # Acquires a resource from stock, yielding it to the given block.
    #
    # @param fiber [Fiber] the fiber the resource will be associated with
    # @return [any] return value of block
    def acquire_from_stock(fiber)
      add_to_stock if (@stock.empty? || @stock.pending?) && @size < @limit
      resource = @stock.shift
      @acquired_resources[fiber] = resource
      yield resource
    ensure
      if resource && @acquired_resources[fiber] == resource
        @acquired_resources.delete(fiber)
        @stock.push resource
      end
    end

    # Creates a resource, adding it to the stock.
    #
    # @return [any] allocated resource
    def add_to_stock
      @size += 1
      resource = @allocator.call
      @stock << resource
    end
  end
end
