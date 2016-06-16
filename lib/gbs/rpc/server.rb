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
                                client.puts(send(:"cmd_#{data[:cmd]}", *data[:args]).to_json)
                            end

                            client.close
                        end
                    end
                end
            end

            def cmd_get_projects
                ProjectManager.projects.map do |project|
                    {
                        name: project.name,
                        last_build: Time.now - Time.now.sec,
                        schedules: project.schedules
                    }
                end
            end

            def cmd_get_artifacts
            end

            def cmd_exit
                exit
            end
        end

        class Client
            def initialize(ip = '127.0.0.1', port = '2552')
                @socket = TCPSocket.new(ip, port)

                Server.instance_methods(false).grep(/^cmd_/).each do |method|
                    cmd = method[4..-1]
                    params = Server.instance_method(method).parameters

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
