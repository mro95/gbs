require 'open3'
require 'shellwords'

module GBS
    class LocalEnvironment
        def initialize
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
                end
            end
        end
    end

    class RemoteEnvironment
        def initialize(base, remote)
            @base = base
            @remote = remote
            @cwd = '/'
        end

        def cd(dir)
            @cwd = dir
        end

        # This approach has about 20ms overhead per command
        def exec(argv)
            sshcmd = %W( ssh #{@remote} -S foo cd #{@cwd} && )
            @base.exec(sshcmd + argv)
        end
    end
end
