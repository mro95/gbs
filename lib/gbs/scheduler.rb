module GBS
    module Scheduler
        def self.init
            @events = []
        end

        def self.start
            @timer = Thread.new do
                loop do
                    next_run = @events.group_by do |event|
                        (event.schedule.next - Time.now).round + 1 # TODO: Improve
                    end.min_by(&:first)

                    sleep next_run.first

                    next_run.last.each(&:run)
                end
            end
        end

        def self.register(project, specifier, task)
            @events << Event.new(project, specifier, task)
        end

        def self.register_special(specifier, &proc)
            @events << SpecialEvent.new(specifier, proc)
        end

        class Event
            attr_reader :schedule, :project

            def initialize(project, specifier, task)
                @project = project
                @specifier = specifier
                @schedule = CronParser.new(specifier)
                @task = task
            end

            def run
                running_task = ProjectManager.run(EnvironmentManager.best_available, @project.name, @task)
            end

            def inspect
                "#{@project.name} event scheduled at #{@specifier}, next run at #{@schedule.next}"
            end
        end

        class SpecialEvent
            attr_reader :schedule

            def initialize(specifier, proc)
                @specifier = specifier
                @schedule = CronParser.new(specifier)
                @proc = proc
            end

            def run
                @proc.call
            end

            def inspect
                "#{@project.name} event scheduled at #{@specifier}, next run at #{@schedule.next}"
            end
        end
    end
end
