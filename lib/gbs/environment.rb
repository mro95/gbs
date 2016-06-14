require 'open3'
require 'shellwords'

module GBS
    class Environment
        def initialize
            @prepared = {}
        end

        def prepared_project?(project_name)
            @prepared[project_name] == true
        end

        def prepared_project(project_name, bool = true)
            @prepared[project_name] = bool
        end

        def load
            exec_return(%W( uptime )).split(' ')[-3..-1].map(&:to_f)
        end

        def exec_return(args)
            exec(args) do |out, err|
                return ((out + err).sort_by(&:first)).map(&:last).join("\n")
            end
        end

        def shell_return(string)
            exec_return %W( bash -c #{string.shellescape} )
        end
    end

    class LocalEnvironment < Environment
        def initialize
            super()

            @cwd = Dir.pwd
        end

        def cd(dir)
            @cwd = dir
        end

        def exec(argv)
            FileUtils.cd(@cwd) do
                Open3.popen3(*argv) do |stdin, stdout, stderr, thread|
                    start = Time.now
                    puts "pid #{thread.pid} cwd #{@cwd}: #{argv.shelljoin}"
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
                                    puts "[%12.6f] %s: %s" % [ time, desc, line ]
                                end
                            end
                        end
                    rescue EOFError => e
                    end

                    puts thread.value

                    return yield(outbuf, errbuf) if block_given?
                end
            end
        end

        def retrieve(remote, lcoal)
            FileUtils.cp(remote, local)
        end
    end

    class RemoteEnvironment < Environment
        def initialize(local, remote)
            super()

            @local = local
            @remote = remote
            @cwd = '.'
        end

        def cd(dir)
            @cwd = dir
        end

        # This approach has about 20ms overhead per command
        def exec(argv, &block)
            sshcmd = %W( ssh #{@remote} -S foo-#{@remote} cd #{@cwd} && )
            @local.exec(sshcmd + argv, &block)
        end

        def retrieve(remote, local)
            @local.exec %W( scp #{@remote}:#{@cwd}/#{remote} #{local} )
        end
    end
end
