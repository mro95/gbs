require 'fileutils'

module GBS
    class Project
        attr_reader :repositories, :tasks, :schedules
        attr_accessor :name

        def initialize
            @name = ''
            @repositories = []
            @tasks = {}
            @schedules = []
        end

        def prepare_workspace(env)
            env.exec %W( mkdir -p #{workspace_directory} )
            env.cd(workspace_directory)

            @repositories.each { |r| r.setup(env) }
        end

        # Run a task
        def run(task_name)
            @tasks[task_name].run
        end

        # Get the path to the directory where this project is built.
        def workspace_directory
            Userdata.workspace_directory(@name)
        end

        # Calls Scheduler::register for every schedule in this project
        def register_schedules
            @schedules.each do |s|
                Scheduler.register(@project, s.specifier, s.block)
            end
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
            @project.schedules << {
                specifier: specifier,
                block: block
            }
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
        def initialize(remote)
            @remote = remote
        end

        def setup(env)
            env.exec %W( git init )
            env.exec %W( git config remote.origin.url #{@remote} )
            env.exec %W( git fetch --tags origin master )
            env.exec %W( git pull origin )
        end
    end
end
