require 'open3'
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
            exec(args) do |out, err, exitstatus|
                return ((out + err).sort_by(&:first)).map(&:last).join("\n")
            end
        end

        def shell_return(string)
            exec_return %W( bash -c #{string.shellescape} )
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
            FileUtils.cd(@cwd) do
                Open3.popen3(*argv) do |stdin, stdout, stderr, thread|
                    start = Time.now
                    Logger.puts "pid #{thread.pid} cwd #{@cwd}: #{argv.shelljoin}"
                    stdin.close
                    stdout.sync = true
                    stderr.sync = true

                    outbuf = []
                    errbuf = []

                    begin
                        until stdout.closed?
                            avail = IO.select([ stdout, stderr ])
                            time = Time.now - start
                            avail.first.each do |io|
                                io.readpartial(4096).each_line do |line|
                                    buf = (io == stdout) ? outbuf : errbuf
                                    desc = (io == stdout) ? 'out' : 'err'

                                    buf << [ time, line ]
                                    Logger.puts "[%12.6f] %s: %s" % [ time, desc, line ]
                                end
                            end
                        end
                    rescue EOFError => e
                    end

                    Logger.puts thread.value

                    return yield(outbuf, errbuf, thread.value.exitstatus) if block_given?
                    return thread.value.exitstatus
                end
            end
        end

        def retrieve(remote, lcoal)
            FileUtils.cp(remote, local)
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
            sshcmd = %W( ssh #{@remote} -S #{controlsocket} cd #{@cwd} && )
            @local.exec(sshcmd + argv, &block)
        end

        def retrieve(remote, local)
            @local.exec %W( scp #{@remote}:#{@cwd}/#{remote} #{local} )
        end
    end
end
