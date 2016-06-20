require 'fileutils'

module GBS
    class Project
        attr_reader :repositories, :tasks, :schedules, :data
        attr_accessor :name

        def initialize
            @name = ''
            @repositories = []
            @tasks = {}
            @schedules = []
            @data = {
                last_build: nil,
                last_success: nil,
                last_failure: nil,
                history: []
            }
        end

        def read_data
            return unless File.exist?(data_path)

            d = Marshal.load(File.read(data_path))
            @data.keys.each do |key|
                @data[key] = d[key] if d.has_key?(key)
            end
        end

        def write_data
            File.write(data_path, Marshal.dump(@data))
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

            result = @tasks[task_name].run(env)

            @data[:last_build] = Time.now

            @data[:last_success] = Time.now if result.status == :success
            @data[:last_failure] = Time.now if result.status == :failure

            @data[:history] << result.status
            @data[:history].unshift if @data[:history].count > 5

            result
        end

        # Get the path to where project data will be stored
        def data_path
            "#{Userdata.data_path}/projects/#{@name}.bin"
        end

        # Get the path to the directory where artifacts from this project are stored.
        def artifact_directory
            "#{Userdata.data_path}/artifacts/#{@name}"
        end

        # Get the path to the directory where this project is built.
        def workspace_directory
            "#{Userdata.data_path}/workspaces/#{@name}"
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
            @project.read_data
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

    class TaskFailed < RuntimeError; end

    class TaskRunner
        attr_reader :status

        def initialize(project, env, block)
            @project = project
            @env = env
            @build = Logger.new_build(project, env)
            @status = nil

            begin
                instance_eval(&block)
                @status = :success
            rescue TaskFailed
                @status = :failure
            end

            @build.finish(@status)
        end

        def `(string)
            @env.shell_return(string)
        end

        def shell(args)
            started = Time.now
            @env.exec(args) do |out, err, exitstatus|
                duration = Time.now - started
                @build.log_command(started, duration, args, out, err, exitstatus)
                raise TaskFailed if exitstatus != 0
            end
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
