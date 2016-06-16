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

            env.prepared_project(@name)
        end

        # Run a task
        def run(env, task_name)
            prepare_workspace(env) unless env.prepared_project?(@name)
            env.cd(workspace_directory)

            @tasks[task_name].run(env)
        end

        # Get the path to the directory where artifacts from this project are stored.
        def artifact_directory
            "#{ENV['HOME']}/.local/share/gbs/artifacts/#{@name}"
        end

        # Get the path to the directory where this project is built.
        def workspace_directory
            "#{ENV['HOME']}/.local/share/gbs/workspaces/#{@name}"
        end

        # Calls Scheduler::register for every schedule in this project
        def register_schedules
            @schedules.each do |s|
                Scheduler.register(self, s[:specifier], s[:task])
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
            @project.tasks[name] = Task.new(@project, block)
        end

        def schedule(specifier, task)
            @project.schedules << {
                specifier: specifier,
                task: task
            }
        end
    end

    class Task
        attr_reader :actions

        def initialize(project, block)
            @project = project
            @block = block
        end

        def run(env)
            TaskRunner.new(@project, env, @block)
        end
    end

    class TaskRunner
        def initialize(project, env, block)
            @project = project
            @env = env
            instance_eval(&block)
        end

        def `(string)
            @env.shell_return(string)
        end

        def shell(args)
            @env.exec(args)
        end

        def artifact(filename, artifact_filename = "#{filename}-#{`git describe --tags`.chomp}")
            FileUtils.mkdir_p(@project.artifact_directory)
            @env.retrieve(filename, "#{@project.artifact_directory}/#{artifact_filename}")
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
