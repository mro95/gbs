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

        def self.finish
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

            def log_command(started, duration, args, out, err, exitstatus)
                @file.puts "cmd [%12.6f] %s" % [ started - @start, args.shelljoin ]

                @file.puts (out.map { |time, line| "out [%12.6f] %s" % [ time, line ] } +
                            err.map { |time, line| "err [%12.6f] %s" % [ time, line ] })
                            .sort_by { |n| n[5..16] }

                @file.puts "ret [%12.6f] exit %i" % [ duration, exitstatus ]

                @subscribers.each { |n| n.puts({
                    msg: 'cmd',
                    started: started,
                    duration: duration,
                    args: args,
                    out: out,
                    err: err,
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
