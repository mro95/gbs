module GBS
    class Project
        attr_reader :repositories, :tasks
        attr_accessor :name

        def initialize
            @name = ''
            @repositories = []
            @tasks = {}
        end
    end

    class ProjectProxy
        attr_reader :project

        def initialize(source)
            @project = Project.new
            instance_eval(source)
        end

        def name(arg)
            @project.name = arg
        end

        def git(path)
            @project.repositories << GitRepository.new(path)
        end

        def task(name, &block)
            @project.tasks[name] = TaskProxy.new(&block)
        end

        def schedule(specifier, &block)
            # TODO: Implement
        end
    end

    class Task
    end

    class TaskProxy
        def initialize(&block)
            @task = Task.new
            instance_eval(&block)
        end

        def shell(str)

        end
    end

    class GitRepository
        def initialize(path)
            @path = path
        end

        def clone(target_dir)
            puts "git clone #{@path} #{target_dir}"
        end
    end
end
