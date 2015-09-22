
require 'jellyfish/urlmap'

module Jellyfish
  class Builder
    def self.app app=nil, &block
      new(app, &block).to_app
    end

    def initialize app=nil, &block
      @use, @map, @run, @warmup = [], nil, app, nil
      instance_eval(&block) if block_given?
    end

    def use middleware, *args, &block
      if @map
        current_map, @map = @map, nil
        @use.unshift(lambda{ |app| generate_map(current_map, app) })
      end
      @use.unshift(lambda{ |app| middleware.new(app, *args, &block) })
    end

    def run app
      @run = app
    end

    def warmup lam=nil, &block
      @warmup = lam || block
    end

    def map path, &block
      (@map ||= {})[path] = block
    end

    def to_app
      run = if @map then generate_map(@map, @run) else @run end
      fail 'missing run or map statement' unless run
      app = @use.inject(run){ |a, m| m.call(a) }
      @warmup.call(app) if @warmup
      app
    end

    private
    def generate_map current_map, app
      mapped = if app then {'' => app} else {} end
      current_map.each do |path, block|
        mapped[path.chomp('/')] = self.class.app(app, &block)
      end
      URLMap.new(mapped)
    end
  end
end
