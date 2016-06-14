module GBS
    module EnvironmentManager
        def self.init
            @local = LocalEnvironment.new
            @remotes = {}

            @remotes['desktop']   = RemoteEnvironment.new(@local, 'homedesktop')
            @remotes['novaember'] = RemoteEnvironment.new(@local, 'nv')
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

        def self.best_available
            all.min_by { |n| n.load[1] } # 5 minute load average
        end
    end
end
