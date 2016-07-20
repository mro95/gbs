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

            @repositories.each { |r| r.setup(env, workspace_directory) }

            env.prepared_project(@name)
        end

        # Run a task
        def run(env, task_name)
            prepare_workspace(env) unless env.prepared_project?(@name)

            @tasks[task_name].run(env)
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
            @project.tasks[name] = Task.new(name, @project, block)
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

        def initialize(name, project, block)
            @name = name
            @project = project
            @block = block
        end

        def run(env)
            TaskRunner.new(@name, @project, env, @block)
        end
    end

    class TaskFailed < RuntimeError; end

    class TaskRunner
        attr_reader :status

        def initialize(name, project, env, block)
            @name = name
            @project = project
            @env = env
            @start = Time.now
            @logger = Logger.new_build(@start, project, env)
            @status = nil

            Thread.new do
                begin
                    instance_eval(&block)
                    @status = :success
                rescue TaskFailed
                    @status = :failure
                end

                @logger.finish(@status)
                ProjectManager.running_tasks.delete(self)

                @project.data[:last_build] = Time.now

                @project.data[:last_success] = Time.now if @status == :success
                @project.data[:last_failure] = Time.now if @status == :failure

                @project.data[:history] << @status
                @project.data[:history].unshift if @project.data[:history].count > 5
            end

            @logger
        end

        def subscribe(sub)
            @logger.subscribe(sub)
        end

        def `(string)
            @env.shell_return(string)
        end

        def shell(args)
            start = Time.now
            @logger.start_command(start, args)

            out, exitstatus = @env.exec(args, chdir: @project.workspace_directory) do |desc, time, line|
                @logger.progress_command(desc, time, line)
            end

            duration = Time.now - start
            @logger.finish_command(duration, exitstatus)

            raise TaskFailed if exitstatus != 0
        end

        def artifact(filename, artifact_filename = "#{filename}-#{`git describe --tags`.chomp}")
            destination = "#{@project.artifact_directory}/#{artifact_filename}"
            FileUtils.mkdir_p(@project.artifact_directory)
            @env.retrieve(File.join(@project.workspace_directory, filename), destination)
            @logger.register_artifact(artifact_filename, File.size(destination))
        end

        def to_json(options = nil)
            {
                project: @project.name,
                task: @name,
                start: @start,
                env: @env.name
            }.to_json
        end
    end

    class GitRepository
        def initialize(remote)
            @remote = remote
        end

        def setup(env, workspace_directory)
            env.exec %W( git init ),                                 chdir: workspace_directory
            env.exec %W( git config remote.origin.url #{@remote} ),  chdir: workspace_directory
            env.exec %W( git fetch --tags origin master ),           chdir: workspace_directory
            env.exec %W( git pull origin ),                          chdir: workspace_directory
        end
    end
end
