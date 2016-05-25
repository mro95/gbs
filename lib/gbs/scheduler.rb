module GBS
    module Scheduler
        def self.init
            @timer = Thread.new do
                sleep 1

                p ProjectManager.projects
            end
        end
    end
end
