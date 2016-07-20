module GBS
    module ProjectManager
        def self.init
            @projects = Userdata.projects
            @projects.each(&:register_schedules)

            @running_tasks = []
        end

        def self.projects
            @projects
        end

        def self.[](name)
            @projects.find { |n| n.name == name }
        end

        def self.run(env, project, task)
            running_task = self[project].run(env, task.to_sym)
            @running_tasks << running_task

            running_task
        end

        def self.running_tasks
            @running_tasks
        end

        def self.shutdown
            @projects.each(&:write_data)
        end
    end
end
