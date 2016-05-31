require 'fileutils'

module GBS
    class Project
        attr_reader :repositories, :tasks
        attr_accessor :name

        def initialize
            @name = ''
            @repositories = []
            @tasks = {}
        end

        # Run a task
        def run(task_name)
            create_workspace

            FileUtils.cd(workspace_directory) do
                @repositories.each { |r| r.setup }
                @tasks[task_name].run
            end
        end

        # Get the path to the directory where this project is built.
        def workspace_directory
            Userdata.workspace_directory(@name)
        end

        # Create the directory that will be used to build this project
        def create_workspace
            FileUtils.mkdir_p(workspace_directory)
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
            @project.tasks[name] = TaskProxy.new(&block).task
        end

        def schedule(specifier, &block)
            Scheduler.register(@project, specifier, &block)
        end
    end

    class Task
        attr_reader :actions

        def initialize
            @actions = []
        end

        def run
            @actions.each(&:call)
        end
    end

    class TaskProxy
        attr_reader :task

        def initialize(&block)
            @task = Task.new
            instance_eval(&block)
        end

        def shell(str)
            @task.actions << lambda do
                system str
            end
        end
    end

    class GitRepository
        def initialize(path)
            @path = path
        end

        def setup
            # TODO: Use popen3
            system "git init"
            system "git config remote.origin.url #{@path}"
            system "git fetch --tags origin master"
            system "git pull origin"
        end
    end
end
