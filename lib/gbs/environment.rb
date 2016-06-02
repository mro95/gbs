require 'open3'
require 'shellwords'

module GBS
    class LocalEnvironment
        def initiailze
        end

        def exec(argv)
            Open3.popen3(*argv) do |stdin, stdout, stderr, thread|
                start = Time.now
                puts "pid #{thread.pid}: #{argv.shelljoin}"
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
