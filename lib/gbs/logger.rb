require 'shellwords'
require 'fileutils'

module GBS
    module Logger
        def self.init
            FileUtils.mkdir_p("#{Userdata.data_path}/logs")
            @main = File.open("#{Userdata.data_path}/logs/#{Time.now.strftime('%Y-%m-%d-%H-%M')}-gbs.log", 'w')
        end

        def self.new_build(project, env)
            build = Build.new(project, env)
        end

        def self.puts(*args)
            @main.puts(*args)
        end

        def self.finish
            @main.close
        end

        class Build
            def initialize(project, env)
                @start = Time.now
                @file = File.open("#{Userdata.data_path}/logs/#{@start.strftime('%Y-%m-%d-%H-%M')}" +
                                  "-#{env.name}-#{project.name}.log", 'w')

                @file.puts "Build started on #{Time.now}"
                @file.puts "Project: #{project.name}"
                @file.puts "Environment: #{env.name}"
            end

            def log_command(started, duration, args, out, err, exitstatus)
                @file.puts "cmd [%12.6f] %s" % [ started - @start, args.shelljoin ]

                @file.puts (out.map { |time, line| "out [%12.6f] %s" % [ time, line ] } +
                            err.map { |time, line| "err [%12.6f] %s" % [ time, line ] })
                            .sort_by { |n| n[5..16] }

                @file.puts "ret [%12.6f] exit %i" % [ duration, exitstatus ]
            end

            def finish
                @file.close
            end
        end
    end
end
