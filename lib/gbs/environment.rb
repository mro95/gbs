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

            stdout, stdout_slave = PTY.open
            stderr, stderr_slave = PTY.open
            pid = spawn(*argv, out: stdout_slave, err: stderr_slave, chdir: @cwd)

            stdout_slave.close
            stderr_slave.close

            start = Time.now
            Logger.puts "pid #{pid} cwd #{@cwd}: #{argv.shelljoin}"

            begin
                until stdout.closed? && stderr.closed?
                    avail = IO.select([ stdout, stderr ])
                    time = Time.now - start
                    avail.first.each do |io|
                        io.readpartial(4096).each_line do |line| # TODO: May not read a full line
                            desc = (io == stdout) ? :out : :err

                            outbuf << [ time, desc, line ]
                            yield(desc, time, line) if block_given?
                            Logger.puts "[%12.6f] %s: %s" % [ time, desc, line ]
                        end
                    end
                end
            rescue Errno::EIO
                # Hopefully this only happens when stdout is closed?
            end

            Process.wait(pid)
            return outbuf, $?.exitstatus # TODO: Possibly thread-unsafe
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
