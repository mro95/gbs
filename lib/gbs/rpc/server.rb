require 'json'
require 'socket'

module GBS
    module RPC
        class Server
            def initialize
                @server = TCPServer.new('127.0.0.1', 2552)

                Thread.start do
                    loop do
                        Thread.start(@server.accept) do |client|
                            client.each_line do |msg|
                                data = JSON.parse(msg.chomp, symbolize_names: true)
                                send(:"cmd_#{data[:cmd]}", client, *data[:args])
                            end

                            client.close
                        end
                    end
                end
            end

            def stop
                @server.close
            end

            def cmd_get_projects(client)
                projects = ProjectManager.projects.map do |filename, project|
                    {
                        name: project.name,
                        schedules: project.schedules,
                        last_build: project.data[:last_build],
                        last_success: project.data[:last_success],
                        last_failure: project.data[:last_failure],
                        history: project.data[:history]
                    }
                end

                client.puts(projects.to_json)
            end

            def cmd_get_environments(client)
                envs = EnvironmentManager.all.map do |env|
                    {
                        name: env.name,
                        loadavg: env.loadavg,
                        load_max: env.load_max
                    }
                end

                client.puts(envs.to_json)
            end

            def cmd_get_recent_builds(client)
                builds = Dir[Userdata.data_path('/logs/builds/*')].sort_by { |n| -File.mtime(n).to_i }.first(5).map do |filename|
                    File.open(filename, 'r') do |file|
                        fields = file.each_line.first(4).map { |n| n.split(': ', 2).last.chomp }
                        [ :start, :result, :project, :env ].zip(fields).to_h
                    end
                end

                client.puts(builds.to_json)
            end

            def cmd_run_task(client, project, task)
                #begin
                    running_task = ProjectManager.run(EnvironmentManager.best_available, project, task)
                    client.puts(running_task.to_json)

                    running_task.subscribe(client)
                #rescue => e
                #    puts e.message
                #    puts e.backtrace.inspect
                #end
            end

            def cmd_running_tasks(client)
                client.puts(ProjectManager.running_tasks.to_json)
            end

            def cmd_reload_userdata(client)
                ProjectManager.reload()
                test = {
                    success: 'true'
                }
                client.puts(test.to_json)
            end

            def cmd_exit(client)
                client.close
                Thread.main.wakeup
            end
        end

        class Client
            attr_reader :socket

            def initialize(ip = '127.0.0.1', port = '2552')
                @socket = TCPSocket.new(ip, port)

                Server.instance_methods(false).grep(/^cmd_/).each do |method|
                    cmd = method[4..-1]
                    params = Server.instance_method(method).parameters.drop(1)

                    self.class.send(:define_method, cmd) do |*args|
                        # TODO: Validate arguments

                        json = { cmd: cmd, args: args }.to_json
                        @socket.puts(json)
                        JSON.parse(@socket.gets, symbolize_names: true) unless cmd == 'exit'
                    end
                end
            end
        end
    end
end
