# -*- coding: binary -*-
require 'msf/ui/console/command_dispatcher'
require 'msf/ui/console/module_argument_parsing'

module Msf
module Ui
module Console

###
#
# A mixin to enable the ModuleCommandDispatcher to leverage module ACTIONs as commands.
#
###
module ModuleActionCommands
  include Msf::Ui::Console::ModuleArgumentParsing

  #
  # Returns the hash of commands specific to auxiliary modules.
  #
  def action_commands
    return {} unless mod.respond_to?(:actions)

    mod.actions.map { |action| [action.name.downcase, action.description] }.to_h
  end

  def commands
    super.merge(action_commands) { |k, old_val, new_val| old_val}
  end

  #
  # Allow modules to define their own commands
  #
  def method_missing(meth, *args)
    if (mod and mod.respond_to?(meth.to_s, true) )

      # Initialize user interaction
      mod.init_ui(driver.input, driver.output)

      return mod.send(meth.to_s, *args)
    end

    action = meth.to_s.delete_prefix('cmd_')
    if mod && mod.kind_of?(Msf::Module::HasActions) && mod.actions.map(&:name).any? { |a| a.casecmp?(action) }
      return do_action(action, *args)
    end

    super
  end

  #
  # Execute the module with a set action
  #
  def do_action(meth, *args)
    action = mod.actions.find { |action| action.name.casecmp?(meth) }
    raise Msf::MissingActionError.new(meth) if action.nil?

    cmd_run(*args, action: action.name)
  end

  def cmd_action_help(action)
    print_line "Usage: " + action.downcase + " [options]"
    print_line
    print_line "Launches a specific module action."
    print @@module_opts.usage
  end

  #
  # Tab completion for the run command
  #
  # @param str [String] the string currently being typed before tab was hit
  # @param words [Array<String>] the previously completed words on the command line.  words is always
  # at least 1 when tab completion has reached this stage since the command itself has been completed
  #
  def cmd_run_tabs(str, words)
    flags = @@module_opts_with_action_support.fmt.keys
    options = tab_complete_option(active_module, str, words)
    flags + options
  end

end
end
end
end
