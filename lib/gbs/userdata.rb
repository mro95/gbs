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

        def self.workspace_directory(project_name)
            "#{ENV['HOME']}/.local/share/gbs/workspaces/#{project_name}"
        end
    end
end
