# frozen_string_literal: true

namespace :job_logs do
  desc "Clean up job log files older than specified days (default: 7 days)"
  task :cleanup, [:days] => :environment do |_t, args|
    days = (args[:days] || 7).to_i
    log_dir = Rails.root.join("log", "jobs")

    unless Dir.exist?(log_dir)
      puts "Job logs directory does not exist: #{log_dir}"
      next
    end

    cutoff_time = days.days.ago
    deleted_count = 0
    total_size = 0

    puts "Cleaning up job log files older than #{days} days (before #{cutoff_time})..."

    Dir.glob(log_dir.join("*.log*")).each do |file_path|
      file_mtime = File.mtime(file_path)

      if file_mtime < cutoff_time
        file_size = File.size(file_path)
        total_size += file_size

        puts "Deleting: #{File.basename(file_path)} (#{file_size / 1024.0} KB, last modified: #{file_mtime})"
        File.delete(file_path)
        deleted_count += 1
      end
    end

    if deleted_count.zero?
      puts "No job log files found older than #{days} days."
    else
      puts "Cleanup completed: Deleted #{deleted_count} file(s), freed #{total_size / 1024.0 / 1024.0} MB"
    end
  end

  desc "List all job log files with their sizes and modification dates"
  task list: :environment do
    log_dir = Rails.root.join("log", "jobs")

    unless Dir.exist?(log_dir)
      puts "Job logs directory does not exist: #{log_dir}"
      next
    end

    files = Dir.glob(log_dir.join("*.log*")).sort_by { |f| File.mtime(f) }.reverse

    if files.empty?
      puts "No job log files found in #{log_dir}"
      next
    end

    puts "Job log files in #{log_dir}:"
    puts "-" * 80

    total_size = 0
    files.each do |file_path|
      file_size = File.size(file_path)
      total_size += file_size
      file_mtime = File.mtime(file_path)

      puts format(
        "%-50s %10.2f KB  %s",
        File.basename(file_path),
        file_size / 1024.0,
        file_mtime.strftime("%Y-%m-%d %H:%M:%S")
      )
    end

    puts "-" * 80
    puts "Total: #{files.count} file(s), #{total_size / 1024.0 / 1024.0} MB"
  end

  desc "Archive old job log files (compress files older than specified days, default: 7)"
  task :archive, [:days] => :environment do |_t, args|
    days = (args[:days] || 7).to_i
    log_dir = Rails.root.join("log", "jobs")

    unless Dir.exist?(log_dir)
      puts "Job logs directory does not exist: #{log_dir}"
      next
    end

    cutoff_time = days.days.ago
    archived_count = 0

    puts "Archiving job log files older than #{days} days (before #{cutoff_time})..."

    Dir.glob(log_dir.join("*.log")).each do |file_path|
      next if File.basename(file_path).end_with?(".gz")

      file_mtime = File.mtime(file_path)

      if file_mtime < cutoff_time
        puts "Archiving: #{File.basename(file_path)}"

        # Gzip the file
        Zlib::GzipWriter.open("#{file_path}.gz") do |gz|
          gz.write(File.read(file_path))
        end

        # Delete the original file
        File.delete(file_path)
        archived_count += 1
      end
    end

    if archived_count.zero?
      puts "No job log files found to archive."
    else
      puts "Archive completed: Compressed #{archived_count} file(s)"
    end
  end
end
