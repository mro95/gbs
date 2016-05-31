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

        def self.register(project, specifier, &block)
            @events << EventProxy.new(project, specifier, &block).event
        end

        class Event
            attr_reader :actions, :schedule, :project

            def initialize(project, specifier)
                @project = project
                @specifier = specifier
                @schedule = CronParser.new(specifier)
                @actions = []
            end

            def run
                @actions.each do |block|
                    instance_eval(&block)
                end
            end

            def inspect
                "#{@project.name} event scheduled at #{@specifier}, next run at #{@schedule.next}"
            end
        end

        class EventProxy
            attr_reader :event

            def initialize(project, specifier, &block)
                @event = Event.new(project, specifier)
                instance_eval(&block)
            end

            def run(task)
                @event.actions << Proc.new { project.run(task) }
            end
        end
    end
end
