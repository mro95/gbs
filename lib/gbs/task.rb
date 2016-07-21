require 'fileutils'

module GBS

    class TaskFailed < RuntimeError; end

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
end
