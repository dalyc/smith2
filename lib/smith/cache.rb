# -*- encoding: utf-8 -*-
module Smith
  class Cache

    include Enumerable

    def initialize
      @cache = {}
    end

    def operator(operator)
      @operator = operator
    end

    def entry(name, options=nil)
      if @cache[name]
        @cache[name]
      else
        if @operator.respond_to?(:call)
          @cache[name] = @operator.call(name, options)
        else
          nil
        end
      end
    end

    alias :[] :entry

    def entries
      @cache.keys.map(&:to_s)
    end

    def invalidate(name)
      @cache.delete(name)
    end

    def each
      @cache.each_value { |v| yield v }
    end

    def empty?
      @cache.empty?
    end

    def exist?(name)
      !@cache[name].nil?
    end

    def size
      @cache.size
    end

    def to_s
      @cache.to_s
    end

    def update(name, entry)
      @cache[name] = entry
    end
  end
end
