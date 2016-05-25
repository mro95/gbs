module GBS
    module Userdata
        def self.projects
            Dir["#{config_path}/projects/*.rb"].map do |filename|
                filecontents = File.read(filename)
                ProjectProxy.new(filecontents).project
            end
        end

        def self.config_path
            "#{ENV['HOME']}/.config/gbs"
        end
    end
end
