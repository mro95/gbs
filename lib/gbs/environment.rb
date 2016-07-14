require 'pty'
require 'shellwords'

module GBS
    class Environment
        attr_reader :loadavg, :load_max

        def initialize
            @prepared = {}
            @load_max = exec_return(%W( nproc )).to_i

            update_loadavg
        end

        def prepared_project?(project_name)
            @prepared[project_name] == true
        end

        def prepared_project(project_name, bool = true)
            @prepared[project_name] = bool
        end

        def update_loadavg
            @loadavg = exec_return(%W( uptime )).split(' ')[-3..-1].map(&:to_f)
        end

        def exec_return(args)
            out, exitstatus = exec(args)
            out.map(&:last).join("\n")
        end

        def shell_return(string)
            exec_return %W( bash -c #{string} )
        end
    end

    class LocalEnvironment < Environment
        def initialize
            @cwd = Dir.pwd

            super()
        end

        def name
            :local
        end

        def cd(dir)
            @cwd = dir
        end

        def exec(argv)
            outbuf = []

            Dir.chdir(@cwd) do
                begin
                    PTY.spawn(*argv) do |stdout, stdin, pid|
                        start = Time.now
                        Logger.puts "pid #{pid} cwd #{@cwd}: #{argv.shelljoin}"
                        stdin.close
                        stdout.sync = true

                        begin
                            stdout.each_line do |line|
                                time = Time.now - start
                                outbuf << [ time, line ]
                                yield(time, line) if block_given?
                            end
                        rescue Errno::EIO => e
                            # Hopefully this only happens when stdout is closed?
                        end

                        Process.wait(pid)
                        return outbuf, $?.exitstatus
                    end
                rescue PTY::ChildExited => e
                    return outbuf, e.status
                end
            end
        end

        def retrieve(remote, local)
            FileUtils.cp(File.join(@cwd, remote), local)
        end
    end

    class RemoteEnvironment < Environment
        def initialize(local, remote)
            @local = local
            @remote = remote
            @cwd = '.'

            super()
        end

        def name
            @remote
        end

        def cd(dir)
            @cwd = dir
        end

        def controlsocket
            Userdata.data_path("/controlsockets/#{@remote}")
        end

        # This approach has about 20ms overhead per command
        def exec(argv, &block)
            sshcmd = %W( ssh #{@remote} -tS #{controlsocket} cd #{@cwd} && )
            @local.exec(sshcmd + argv, &block)
        end

        def retrieve(remote, local)
            @local.exec %W( scp #{@remote}:#{@cwd}/#{remote} #{local} )
        end
    end
end
