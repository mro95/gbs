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

        def self.register(project, specifier, proc)
            @events << Event.new(project, specifier, proc)
        end

        class Event
            attr_reader :actions, :schedule, :project

            def initialize(project, specifier, proc)
                @project = project
                @specifier = specifier
                @schedule = CronParser.new(specifier)
                @proc = proc
            end

            def run
                EventRunner.new(@project, @proc)
            end

            def inspect
                "#{@project.name} event scheduled at #{@specifier}, next run at #{@schedule.next}"
            end
        end

        class EventRunner
            attr_reader :event

            def initialize(project, block)
                @project = project
                instance_eval(&block)
            end

            def run(task)
                @project.run(EnvironmentManager.best_available, task)
            end
        end
    end
end
