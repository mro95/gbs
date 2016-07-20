require 'shellwords'
require 'fileutils'

module GBS
    module Logger
        def self.init
            FileUtils.mkdir_p("#{Userdata.data_path}/logs/builds")
            @main = File.open("#{Userdata.data_path}/logs/#{Time.now.strftime('%Y-%m-%d-%H-%M')}-gbs.log", 'w')
        end

        def self.new_build(start, project, env)
            build = BuildLogger.new(start, project, env)
        end

        def self.puts(*args)
            @main.puts(*args)
        end

        def self.shutdown
            @main.close
        end

        class BuildLogger
            def initialize(start, project, env)
                @subscribers = []
                @artifacts = []
                @start = start
                @project = project
                @env = env

                @file = File.open("#{Userdata.data_path}/logs/builds/#{@start.strftime('%Y-%m-%d-%H-%M-%S')}" +
                                  "-#{env.name}-#{project.name}.log", 'w')

                @buffer = ""

                log "Build started on: #{@start}"

                @file.write "Build result: "
                @resultpos = @file.pos
                @file.puts "       " # leave some space to write 'success', 'failure' or 'ucancel'

                log "Project: #{@project.name}"
                log "Environment: #{@env.name}"
            end

            def log(msg)
                @file.puts msg

                @subscribers.each do |sub|
                    begin
                        sub.puts(msg)
                    rescue IOError
                        @subscribers.delete(sub)
                    end
                end

                @buffer << "#{msg}\n"
            end

            def subscribe(socket)
                socket.write @buffer
                @subscribers << socket
            end

            def start_command(timestamp, args)
                log "cmd [%12.6f] %s" % [ timestamp - @start, args.shelljoin ]
            end

            def progress_command(desc, time, line)
                log "%s [%12.6f] %s" % [ desc, time, line ]
            end

            def finish_command(duration, exitstatus)
                log "ret [%12.6f] exit %i" % [ duration, exitstatus ]
            end

            def register_artifact(name, size)
                @artifacts << { name: name, size: size }
            end

            def finish(result)
                @file.seek(@resultpos)
                @file.write(result.to_s[0..7])
                @file.close

                @subscribers.each { |n| n.puts("Build result: #{result}") }
            end
        end
    end
end
