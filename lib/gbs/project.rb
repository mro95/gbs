require 'fileutils'

module GBS

    ##
    # Represents a project that can be built and/or tested.
    #
    # Between instances of GBS, the contents of @data is stored on disk. #write_data is called by
    # ProjectManager.shutdown when GBS exits and #read_data is called by ProjectProxy#name which is in turn called by
    # project configuration files.
    #
    # ProjectProxy is used to construct a Project from a configuration file.
    #
    class Project

        # A unique identifier for this project.
        attr_accessor :name

        # A list of repositories (eg. git) that contains this project.
        attr_reader :repositories

        # The tasks that can be executed for this project (build, test...).
        attr_reader :tasks

        # A list of events that determine when tasks for this project should run automatically.
        attr_reader :schedules

        # Hash of data describing recent build results.
        attr_reader :data


        ##
        # Initialize a new Project with empty attributes.
        #
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

        ##
        # Load @data contents from disk.
        #
        def read_data
            return unless File.exist?(data_path)

            d = Marshal.load(File.read(data_path))
            @data.keys.each do |key|
                @data[key] = d[key] if d.has_key?(key)
            end
        end

        ##
        # Save the contents of @data to disk.
        #
        def write_data
            File.write(data_path, Marshal.dump(@data))
        end

        ##
        # Create the workspace directory and set up each repository. Calls Environment#prepared_project to mark this
        # project as prepared on the environment.
        #
        # +env+::
        #   Environment to work on
        #
        def prepare_workspace(env)
            env.exec %W( mkdir -p #{workspace_directory} )

            @repositories.each { |r| r.setup(env, workspace_directory) }

            env.prepared_project(@name)
        end

        ##
        # Run a task by name. Returns the created TaskRunner.
        #
        # +env+::
        #   Environment to run the task on.
        #
        # +task_name+::
        #   Name of task to run, as a Symbol.
        #
        def run(env, task_name)
            prepare_workspace(env) unless env.prepared_project?(@name)

            @tasks[task_name].run(env)
        end

        ##
        # Get the path to where project data will be stored. (See #read_data and #write_data)
        #
        def data_path
            "#{Userdata.data_path}/projects/#{@name}.bin"
        end

        ##
        # Get the path to the directory where artifacts from this project are stored.
        #
        def artifact_directory
            "#{Userdata.data_path}/artifacts/#{@name}"
        end

        ##
        # Get the path to the directory where this project is built.
        #
        def workspace_directory
            "#{Userdata.data_path}/workspaces/#{@name}"
        end

        ##
        # Calls Scheduler.register for every schedule in this project
        #
        def register_schedules
            @schedules.each do |s|
                Scheduler.register(self, s[:specifier], s[:task])
            end
        end
    end

    ##
    # A proxy used to construct a Project using DSL in configuration files.
    #
    # Example configuration file:
    #
    #   name 'screentool'
    #   git 'github:Darkwater/screentool'
    #
    #   schedule '0 1 * * *', :build
    #
    #   task :build do
    #       shell %W( dub build )
    #
    #       artifact 'screentool'
    #   end
    #
    class ProjectProxy

        # The Project that's being constructed.
        attr_reader :project

        ##
        # Construct a new Project.
        #
        # +source::
        #   Ruby source code that describes the project using DSL.
        #
        def initialize(source)
            @project = Project.new
            instance_eval(source)
        end

        ##
        # Give this project a name. Also loads data, see Project#read_data.
        #
        # +arg+::
        #   Name as a Symbol.
        #
        def name(arg)
            @project.name = arg
            @project.read_data
        end

        ##
        # Add a Git repository. See GitRepository.
        #
        # +path+::
        #   Location of remote repository.
        #
        def git(path)
            @project.repositories << GitRepository.new(path)
        end

        ##
        # Add a Task. See TaskRunner.
        #
        # +name+::
        #   Type of task. Can be :build.
        #
        def task(name, &block) # :yields:
            @project.tasks[name] = Task.new(name, @project, block)
        end

        ##
        # Schedule a Task to run regularly.
        #
        # +specifier+::
        #   A cron specifier. (eg. +'0 2 * * *'+)
        #
        # +task+::
        #   Name of the task to run, as a Symbol.
        def schedule(specifier, task)
            @project.schedules << {
                specifier: specifier,
                task: task
            }
        end
    end

    ##
    # Represents a Git repository.
    #
    class GitRepository

        ##
        # Create a new Git repository.
        #
        # +remote+::
        #   Location of remote repository.
        #
        def initialize(remote)
            @remote = remote
        end

        ##
        # Set up this repository in a directory on an environment.
        #
        # +env+::
        #   Environment to set up on.
        #
        # +workspace_directory+::
        #   Directory to clone into.
        #
        def setup(env, workspace_directory)
            env.exec %W( git init ),                          chdir: workspace_directory
            env.exec %W( git remote add origin #{@remote} ),  chdir: workspace_directory
            env.exec %W( git fetch --tags origin master ),    chdir: workspace_directory
            env.exec %W( git checkout origin/master ),        chdir: workspace_directory
        end
    end
end
