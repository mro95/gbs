module GBS
    module EnvironmentManager
        def self.init
            @local = LocalEnvironment.new
            @remotes = {}

            @remotes['novaember'] = RemoteEnvironment.new(@local, 'nv')

            Scheduler.register_special('* * * * *') do
                EnvironmentManager.update_loadavgs
            end
        end

        def self.local
            @local
        end

        def self.remotes
            @remotes.values
        end

        def self.all
            [ @local ] + remotes
        end

        def self.[](name)
            @remotes[name]
        end

        def self.update_loadavgs
            all.each(&:update_loadavg)
        end

        def self.best_available
            all.min_by { |n| n.loadavg[1] } # 5 minute load average
        end
    end
end
