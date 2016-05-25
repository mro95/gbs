module GBS
    module ProjectManager
        def self.init
            @projects = Userdata.projects
        end

        def self.projects
            @projects
        end
    end
end
