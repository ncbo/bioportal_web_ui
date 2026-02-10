# frozen_string_literal: true

namespace :image_cleaner do
  desc 'Find unused images (dry run)'
  task find_unused_images: :environment do
    find_and_report_unused_images(dry_run: true)
  end

  desc 'Delete unused images (DESTRUCTIVE - use with caution)'
  task delete_unused_images: :environment do
    print 'This will DELETE files. Are you sure? (yes/no): '
    $stdout.flush
    confirmation = $stdin.gets.chomp

    unless confirmation.downcase == 'yes'
      puts 'Cancelled.'
      exit
    end

    find_and_report_unused_images(dry_run: false)
  end

  def find_and_report_unused_images(dry_run:)
    puts 'Searching for images...'
    images = Dir.glob('app/assets/images/**/*').select { |f| File.file?(f) }

    puts "Found #{images.count} image files"
    puts dry_run ? "\n[DRY RUN MODE - No files will be deleted]\n" : "\n[DELETION MODE]\n"

    unused_images = []
    images.each do |image_path|
      print "Checking #{image_path}... "

      filename = File.basename(image_path)
      name_without_ext = File.basename(image_path, '.*')

      search_patterns = [filename, name_without_ext]
      found = search_patterns.any? do |pattern|
        escaped_pattern = Shellwords.escape(pattern)
        result = `grep -rI --include="*.rb" --include="*.erb" --include="*.haml" --include="*.scss" --include="*.css" \
                  --include="*.js" -l #{escaped_pattern} app/ vendor/ 2>/dev/null`
        !result.strip.empty?
      end

      if found
        puts 'in use'
      else
        puts 'UNUSED'
        unused_images << image_path

        unless dry_run
          begin
            File.delete(image_path)
            puts '  Deleted'
          rescue StandardError => e
            puts "  ERROR: #{e.message}"
          end
        end
      end
    end

    puts "\n#{'=' * 60}"
    puts "Summary: #{unused_images.count} unused images #{dry_run ? 'found' : 'deleted'}"
    puts '=' * 60

    return unless dry_run && unused_images.any?

    puts "\nTo delete these files, run:"
    puts '  rails image_cleaner:delete_unused_images'
  end
end
