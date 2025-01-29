# lib/tasks/generate_component_previews.rake

namespace :component_previews do
  desc "Generate previews for all components"
  task generate: :environment do
    components_path = Rails.root.join("app/components")
    components = Dir.glob("#{components_path}/**/*_component.rb")

    components.each do |component_path|
      component_name = File.basename(component_path, "_component.rb")
      preview_path = Rails.root.join("test/components/previews/#{component_name}_preview.rb")

      # Skip if the preview already exists
      next if File.exist?(preview_path)

      File.open(preview_path, "w") do |file|
        file.puts("class #{component_name.camelize}Preview < ViewComponent::Preview")
        file.puts("  def default")
        file.puts("    # Initialize the component with any necessary data")
        file.puts("    component = #{component_name.camelize}Component.new")

        file.puts("    # Add any necessary data or context to the component")
        file.puts("    # component.some_data = some_value")

        file.puts("    # Render the component")
        file.puts("    render(component)")
        file.puts("  end")
        file.puts("end")
      end

      puts "Generated preview for #{component_name}"
    end
  end
end
