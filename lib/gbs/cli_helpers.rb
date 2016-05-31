module GBS
    module CLIHelpers
        def self.parse_options(options)
            options.map do |opt|
                opt.unshift('') if opt[0][0..1] == '--' # short opt optional

                {
                    short: opt[0],
                    long:  opt[1],
                    desc:  opt[2..-1].join(' '),
                    id:    opt[1][2..-1].to_sym # long opt without dashes
                }
            end
        end

        def self.send_help(options)
            puts "Usage: #{$0} [option...] project [task...]"
            puts
            options.each do |opt|
                puts '  %-2s  %-12s  %s' % [ opt[:short], opt[:long], opt[:desc] ]
            end
        end

        def self.parse_arguments(options, argv)
            out = argv.select { |arg| arg[0] == '-' }.map do |arg|
                opt = options.find { |opt| opt[:short] == arg || opt[:long] == arg }
                if opt.nil?
                    warn "Unknown option: #{arg}"
                    exit 1
                end

                [ opt[:id], true ]
            end

            [ out.to_h, ARGV.reject { |arg| arg[0] == '-' } ]
        end
    end
end
