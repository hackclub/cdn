# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  user = User.first || User.create!(
    hca_id: 'dev_user',
    email: 'dev@example.com',
    name: 'Dev User'
  )

  provenances = [:web, :api, :slack, :rescued]

  10.times do |i|
    # Create dummy file content
    content = "This is test file #{i} content. " * 100

    # Create blob (ActiveStorage handles file storage to ./storage/ in dev)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: "test_file_#{i}.jpg",
      content_type: 'image/jpeg'
    )

    # Create upload record
    provenance = provenances.sample
    Upload.create!(
      user: user,
      blob: blob,
      provenance: provenance,
      original_url: provenance == :rescued ? "https://hel1.cdn.hackclub.com/old_file_#{i}.jpg" : nil,
      created_at: rand(30.days.ago..Time.current)
    )
  end

  puts "Created #{Upload.count} sample uploads for #{user.name}"
  puts "Provenance breakdown:"
  Upload.group(:provenance).count.each do |prov, count|
    puts "  #{prov}: #{count}"
  end
end
