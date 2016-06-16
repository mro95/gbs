module GBS
    module Scheduler
        def self.init
            @events = []
        end

        def self.start
            puts "Starting Scheduler thread..."

            @timer = Thread.new do
                loop do
                    next_run = @events.group_by do |event|
                        (event.schedule.next - Time.now).round + 1 # TODO: Improve
                    end.min_by(&:first)

                    puts "Waiting #{next_run.first} seconds to run #{next_run.last.map{|n| n.project.name }.join(', ')}"

                    sleep next_run.first

                    next_run.last.each(&:run)
                end
            end
        end

        def self.register(project, specifier, task)
            @events << Event.new(project, specifier, task)
        end

        class Event
            attr_reader :actions, :schedule, :project

            def initialize(project, specifier, task)
                @project = project
                @specifier = specifier
                @schedule = CronParser.new(specifier)
                @task = task
            end

            def run
                @project.run(EnvironmentManager.best_available, @task)
            end

            def inspect
                "#{@project.name} event scheduled at #{@specifier}, next run at #{@schedule.next}"
            end
        end
    end
end
