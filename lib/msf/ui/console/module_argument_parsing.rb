
# -*- coding: binary -*-
require 'msf/ui/console/command_dispatcher'

module Msf
module Ui
module Console

###
#
# A centralized mixin to ensure that options are consistently parsed across all module types
# when running a module's cmd_run/cmd_check/cmd_exploit arguments
#
###
module ModuleArgumentParsing

  # Options which are standard and predictable across all modules
  @@module_opts = Rex::Parser::Arguments.new(
    '-h' => [ false, 'Help banner.'                                          ],
    '-j' => [ false, 'Run in the context of a job.'                          ],
    '-J' => [ false, 'Force running in the foreground, even if passive.'     ],
    '-o' => [ true,  'A comma separated list of options in VAR=VAL format.'  ],
    '-q' => [ false, 'Run the module in quiet mode with no output'           ]
  )

  @@module_opts_with_action_support = Rex::Parser::Arguments.new(@@module_opts.fmt.merge(
    '-a' => [ true, 'The action to use. If none is specified, ACTION is used.']
  ))

  @@exploit_opts = Rex::Parser::Arguments.new(@@module_opts.fmt.merge(
    '-e' => [ true,  'The payload encoder to use.  If none is specified, ENCODER is used.' ],
    '-f' => [ false, 'Force the exploit to run regardless of the value of MinimumRank.'    ],
    '-n' => [ true,  'The NOP generator to use.  If none is specified, NOP is used.'       ],
    '-p' => [ true,  'The payload to use.  If none is specified, PAYLOAD is used.'         ],
    '-t' => [ true,  'The target index to use.  If none is specified, TARGET is used.'     ],
    '-z' => [ false, 'Do not interact with the session after successful exploitation.'     ]
  ))

  def parse_check_opts(args)
    help_cmd = proc do |_result|
      cmd_check_help
    end
    parse_opts(@@module_opts_with_action_support, args, help_cmd: help_cmd)&.slice(:datastore_options)
  end

  def parse_run_opts(args, action: nil)
    help_cmd = proc do |result|
      if result[:action].nil?
        cmd_run_help
      else
        cmd_action_help(action)
      end
    end

    parse_opts(@@module_opts_with_action_support, args, help_cmd: help_cmd)
  end

  def parse_exploit_opts(args)
    help_cmd = proc do |_result|
      cmd_exploit_help
    end
    parse_opts(@@exploit_opts, args, help_cmd: help_cmd)&.except(:action)
  end

  protected

  def parse_opts(opts, args, help_cmd:, action: nil)
    result = {
      jobify: false,
      quiet: false,
      datastore_options: {},
      action: action || mod.datastore['ACTION']
    }
    datastore_options = result[:datastore_options]

    opts.parse(args) do |opt, _idx, val|
      case opt
      when '-e'
        result[:encoder] = val
      when '-f'
        result[:force] = true
      when '-j'
        result[:jobify] = true
      when '-J'
        result[:jobify] = false
      when '-n'
        result[:nop] = val
      when '-o'
        if val.nil?
          help_cmd.call result
          return
        end
        val << '=' unless val.include?('=')
        val.split(',').each do |opt|
          name, value = opt.split('=', 2)
          datastore_options[name] = value.strip
        end
      when '-p'
        result[:payload] = val
      when '-t'
        result[:target] = val.to_i
      when '-z'
        result[:background] = true
      when '-a'
        result[:action] = val
      when '-q'
        result[:quiet] = true
      when '-h'
        help_cmd.call result
        return
      else
        if val && val[0] == '-'
          help_cmd.call result
          return
        end

        if resembles_datastore_assignment?(val)
          name, value = val.split('=', 2)
          datastore_options[name] = value.strip
        elsif resembles_rhost_value?(val)
          if !datastore_options['RHOSTS']
            datastore_options['RHOSTS'] = val
          else
            datastore_options['RHOSTS'] = "#{datastore_options['RHOSTS']} #{val}"
          end
        else
          help_cmd.call result
          return
        end
      end
    end

    result
  end

  def resembles_datastore_assignment?(val)
    return false unless val

    valid_option_regex = /^\w+=.*/
    valid_option_regex.match?(val)
  end

  def resembles_rhost_value?(val)
    return false unless val

    URI.parse(val)
    true
  rescue URI::Error => _e
    false
  end
end
end
end
end
