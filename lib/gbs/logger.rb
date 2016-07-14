require 'shellwords'
require 'fileutils'

module GBS
    module Logger
        def self.init
            FileUtils.mkdir_p("#{Userdata.data_path}/logs/builds")
            @main = File.open("#{Userdata.data_path}/logs/#{Time.now.strftime('%Y-%m-%d-%H-%M')}-gbs.log", 'w')
        end

        def self.new_build(project, env)
            build = BuildLogger.new(project, env)
        end

        def self.puts(*args)
            @main.puts(*args)
        end

        def self.shutdown
            @main.close
        end

        class BuildLogger
            def initialize(project, env)
                @subscribers = []
                @artifacts = []
                @project = project
                @env = env

                @start = Time.now
                @file = File.open("#{Userdata.data_path}/logs/builds/#{@start.strftime('%Y-%m-%d-%H-%M-%S')}" +
                                  "-#{env.name}-#{project.name}.log", 'w')

                @file.puts "Build started on: #{@start}"

                @file.write "Build result: "
                @resultpos = @file.pos
                @file.puts "       " # leave some space to write 'success', 'failure' or 'ucancel'

                @file.puts "Project: #{@project.name}"
                @file.puts "Environment: #{@env.name}"
            end

            def subscribe(socket)
                socket.puts({
                    msg: 'meta',
                    start: @start,
                    project: @project.name,
                    env: @env.name
                }.to_json)

                @subscribers << socket
            end

            def start_command(timestamp, args)
                @file.puts "cmd [%12.6f] %s" % [ timestamp - @start, args.shelljoin ]

                @subscribers.each { |n| n.puts({
                    msg: 'start_command',
                    started: timestamp,
                    args: args,
                }.to_json) }
            end

            def progress_command(time, line)
                @file.puts "out [%12.6f] %s" % [ time, line ]

                @subscribers.each { |n| n.puts({
                    msg: 'progress_command',
                    output: [ [ time, line ] ],
                }.to_json) }
            end

            def finish_command(duration, exitstatus)
                @file.puts "ret [%12.6f] exit %i" % [ duration, exitstatus ]

                @subscribers.each { |n| n.puts({
                    msg: 'finish_command',
                    duration: duration,
                    exitstatus: exitstatus
                }.to_json) }
            end

            def register_artifact(name, size)
                @artifacts << { name: name, size: size }
            end

            def finish(result)
                @file.seek(@resultpos)
                @file.write(result.to_s[0..7])
                @file.close

                @subscribers.each { |n| n.puts({
                    msg: 'done',
                    result: result,
                    duration: Time.now - @start,
                    artifacts: @artifacts
                }.to_json) }
            end
        end
    end
end
