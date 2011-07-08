require 'pp'

module Smith
  class Agent

    include Logger

    def initialize(options={})
      Smith.on_error = proc {|e| pp e}

      @queues = Cache.new
      @queues.operator ->(name){Messaging.new(name)}

      @default_message_options = {:ack => true, :durable => true}

      agent_queue
      acknowledge_start
      start_keep_alive
    end

    def get_message(queue, options={}, &block)
      queues(queue).receive_message(options) do |header,message|
        block.call(header, message)
      end
    end

    private

    def acknowledge_start
      agent_data = {:pid => $$, :name => self.class.to_s, :started_at => Time.now.utc}
      Smith::Messaging.new(:acknowledge_start).send_message(agent_data, message_opts)
    end

    def acknowledge_stop
      agent_data = {:pid => $$, :name => self.class.to_s}
      Smith::Messaging.new(:acknowledge_stop).send_message(agent_data, message_opts)
    end

    def start_keep_alive
      send_keep_alive(queues(:keep_alive))
      EventMachine::add_periodic_timer(1) do
        send_keep_alive(queues(:keep_alive))
      end
    end

    def agent_queue
      queue_name = "agent.#{self.class.to_s.snake_case}"
      logger.debug("Setting up agent queue: #{queue_name}")
      queues(queue_name).receive_message do |header, message|
        case message
        when 'stop'
          acknowledge_stop
          Smith.stop
        else
          logger.warn("Unkown message: #{message}")
        end
      end
    end

    def message_opts(options={})
      options.merge(@default_message_options)
    end

    def queues(queue_name)
      @queues.entry(queue_name)
    end

    def send_keep_alive(queue)
      queue.consumers? do |queue|
        queue.send_message({:name => self.class.to_s, :time => Time.now.utc}, message_opts(:durable => false))
      end
    end
  end
end
