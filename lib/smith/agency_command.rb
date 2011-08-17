# encoding: utf-8

module Smith
  class AgencyCommand
    class UnkownCommandError < RuntimeError; end

    include Logger

    # Load and run the command specified. This method takes:
    # +target+ which is either a list of agents or the agency
    # +vars+ variables to be passed in to the command. This
    # takes the form of a hash and accessor methods are generated
    # named after the key of the hash.
    # +opts+ options for the AgencyCommand class. At the moment
    # only :auto_load is supported.
    #
    def self.run(command, target, vars, opts={})
      logger.debug("Agency command: #{command}#{(target.empty?) ? '' : " #{target.join(', ')}"}.")

      load_command(command) unless opts[:auto_load] == false

      Smith::AgencyCommands.const_get(Extlib::Inflection.camelize(command)).new(target).tap do |clazz|
        clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
          instance_variable_set(:"@target", target)
          def target; @target; end
        EOM

        vars.each do |k,v|
          clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
            instance_variable_set(:"@#{k}", v)
            def #{k}; @#{k}; end
          EOM
        end

        # FIXME. target is being used for both the target and any arguments if
        # this is the way it's going to be it should be renamed
        clazz.execute(target)
      end
    end

    protected

    # The options are always in this form:
    #
    # command option [agent|agency]
    def verify_options(opts)
    end

    def send_agent_control_message(agent, message)
      Smith::Messaging.new(agent.control_queue_name).send_message(message)
    end

    private

    # Load the command from the lib/smith/agency_commands directory.
    def self.load_command(cmd)
      cmd_path = Smith.root_path.join('lib').join("smith").join('agency_commands').join(cmd.to_s)
      if cmd_path.sub_ext('.rb').exist?
        require cmd_path
      else
        raise UnkownCommandError, "Command class does not exist: #{cmd}"
      end
    end
  end
end