module GBS
    module Userdata
        def self.projects
            Dir["#{config_path}/projects/*.rb"].map do |filename|
                filecontents = File.read(filename)
                ProjectProxy.new(filecontents).project
            end
        end

        def self.config_path(cont = '')
            "#{ENV['HOME']}/.config/gbs" + cont
        end

        def self.data_path(cont = '')
            "#{ENV['HOME']}/.local/share/gbs" + cont
        end

        def self.create_directories
            FileUtils.mkdir_p("#{data_path}/projects")
            FileUtils.mkdir_p("#{data_path}/controlsockets")
        end
    end
end
