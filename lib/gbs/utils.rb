module GBS
    module Utils
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

        def self.tabularize(table, options = {})
            colsizes = table.transpose.map { |n| n.map(&:length_term).max }

            if options[:minsizes]
                colsizes = colsizes.zip(options[:minsizes]).map(&:compact).map(&:max)
            end

            padding = options[:padding] || 2

            table.map { |row| row.each_with_index.map { |cell, i| cell.ljust_term(colsizes[i]) }.join(' ' * padding) }
        end

        def self.time_ago(time)
            delta = Time.now - time

            days    = ( delta / (60 * 60 * 24) ).to_i
            hours   = ( delta / (60 * 60) % 24 ).to_i
            minutes = ( delta / (60)      % 60 ).to_i
            seconds = ( delta             % 60 ).to_i

            (delta < 60          ) ? "#{seconds}s ago" :
            (delta < 60 * 60     ) ? "#{minutes}m #{seconds}s ago" :
            (delta < 60 * 60 * 24) ? "#{hours}h #{minutes}m ago" :
                                     "#{days}d #{hours}h ago"
        end
    end
end

class String
    # Helper string format methods

    # Define String#red, etc for colored terminal output
    %i(black red green yellow blue magenta cyan white).each_with_index do |name, index|
        define_method name do
            "\e[3#{index}m#{self}\e[0m"
        end
    end

    def bold
        "\e[1m#{self}\e[0m"
    end

    def indent(num)
        self.lines.map { |line| ' ' * num + line }.join
    end

    # Version of #length that ignores terminal escape sequences
    def length_term
        self.gsub(/\e\[[^m]*m/, '').length
    end

    # Version of #ljust that ignores terminal escape sequences
    def ljust_term(num)
        padding = (num - length_term)
        return self if padding <= 0
        self + ' ' * padding
    end
end
