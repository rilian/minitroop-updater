require 'faraday'
require 'debugger'

trooper_names = %w[
  supril4-1
]

punch_troopers = %w[
  fenchenko
]

@failed_troopers = []
@success_troopers = []
@can_upgrade_troopers = []

trooper_names.each do |trooper_name|
  puts "Working on #{trooper_name}"

  hq_url = "http://#{trooper_name}.minitroopers.com/hq"

  begin
    response = Faraday.get hq_url

    if response.success?
      hq_page = response.body

      # Find chk
      chk_arr = hq_page.scan(/miss[^c]+chk=([a-zA-Z0-9]+)/).flatten
      chk = chk_arr.size > 0 ? chk_arr.first : nil

      raise 'Could not find chk!' unless chk
      puts "chk=#{chk}"

      # Unlock mission if possible
      sleep(1)
      puts 'Unlocking mission'
      unlock_response = Faraday.get "http://#{trooper_name}.minitroopers.com/unlock?mode=miss;chk=#{chk}"

      # Perform 3 fights
      3.times do
        sleep(1)
        puts 'Fighting'
        conn = Faraday.new(url: "http://#{trooper_name}.minitroopers.com") do |faraday|
          faraday.request :url_encoded # form-encode POST params
        end

        conn.post '/b/battle', { chk: chk, friend: punch_troopers.sample }
      end

      # Check if can upgrade
      sleep(1)
      puts 'Checking if can upgrade'
      upgrade_page = Faraday.get("http://#{trooper_name}.minitroopers.com/t/0").body
      upgrade_cost = upgrade_page.scan(/Upgrade\s+for\s+([0-9]+)/).flatten.first.to_i
      have_money = upgrade_page.scan(/([0-9]+)\s+<\/div>\s+<div\s+class="power/).flatten.first.to_i
      if upgrade_cost <= have_money
        @can_upgrade_troopers << trooper_name
      end

      @success_troopers << trooper_name
      puts 'Finished successfully'
      sleep(1)
    else
      @failed_troopers << trooper_name
      puts "Error getting #{search_url}"
      puts "Status #{response.status}"
      puts "Headers #{response.headers}"
      puts "Body #{response.body}"
    end
  rescue Exception => e
    puts "Error:\n\n#{e.message}\n\n#{e.backtrace}\n"
  end
end

puts "Success: #{@success_troopers.inspect}"
puts "Fail: #{@failed_troopers.inspect}"
if @can_upgrade_troopers.size > 0
  puts 'Upgrade:'
  @can_upgrade_troopers.each do |trooper_name|
    puts "http://#{trooper_name}.minitroopers.com/hq"
  end
end
