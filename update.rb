require 'faraday'
require 'faraday-cookie_jar'
require 'debugger'

TROOPERS = YAML::load(File.open('troopers.yml'))
SKILLS = YAML::load(File.open('skills.yml'))

SLEEP = 0.1
RETRY_SEC = 30.0
DEBUG = false
TRY_UPGRADE = false
@can_upgrade_troopers = []
@total_money = 0
@log_file = File.open("#{Time.now.strftime('%d-%b_%H-%M-%S')}_minitroopers.log", 'w')

def log(str)
  @log_file.write("#{str}\r\n")
  puts str
end

#def best_skill(skill_ids)
#  indexes = []
#  skill_numbers = SKILLS['skills'].collect { |s| s[:number] }
#  Array.wrap(skill_ids).each do |skill_id|
#    indexes << skill_numbers.index(skill_id)
#  end
#end

TROOPERS['troopers'].each do |trooper_name|
  log "Working on #{trooper_name} #{TROOPERS['troopers'].index(trooper_name) + 1} of #{TROOPERS['troopers'].count}"
  conn = Faraday.new(url: "http://#{trooper_name}.minitroopers.com") do |faraday|
    faraday.request :url_encoded # form-encode POST params
    faraday.response :logger if DEBUG
    faraday.use :cookie_jar
    faraday.adapter Faraday.default_adapter
  end

  success = false
  while !success
    begin
      hq_page = conn.get('/hq').body
      success = true
    rescue
      puts "errors. retrying in #{RETRY_SEC} sec"
      sleep RETRY_SEC
    end
  end

  if !hq_page.scan(/New recruit available!/).empty?
    log 'Adding new recruit'
    sleep(SLEEP)

    success = false
    while !success
      begin
        conn.get '/history'
        success = true
      rescue
        puts "errors. retrying in #{RETRY_SEC} sec"
        sleep RETRY_SEC
      end
    end

    sleep(SLEEP)

    success = false
    while !success
      begin
        hq_page = conn.get('/hq').body
        success = true
      rescue
        puts "errors. retrying in #{RETRY_SEC} sec"
        sleep RETRY_SEC
      end
    end
  end

  # Find current money
  had_money = hq_page.scan(/([0-9]+)\s+<\/div>\s+<div\s+class="power/).flatten.first.to_i

  # Find chk
  chk_arr = hq_page.scan(/miss[^c]+chk=([a-zA-Z0-9]+)/).flatten
  chk = chk_arr.size > 0 ? chk_arr.first : nil

  log chk ? "chk=#{chk}" : 'Could not find chk!'

  if chk
    # Unlock mission if possible
    if had_money >= 5
      sleep(SLEEP)
      log 'Unlocking mission'

      success = false
      while !success
        begin
          conn.get "/unlock?mode=miss;chk=#{chk}"
          success = true
        rescue
          puts "errors. retrying in #{RETRY_SEC} sec"
          sleep RETRY_SEC
        end
      end
    end

    # Perform 3 Missions
    3.times do |index|
      sleep(SLEEP)
      log "Mission #{index}"

      success = false
      while !success
        begin
          conn.get "b/mission?chk=#{chk}"
          success = true
        rescue
          puts "errors. retrying in #{RETRY_SEC} sec"
          sleep RETRY_SEC
        end
      end
    end

    fights_number = [hq_page.scan(/\/b\/opp/).count, 3].max
    # Perform 3 or 4 Fights
    fights_number.times do |index|
      sleep(SLEEP)
      log "Fighting #{index}"

      success = false
      while !success
        begin
          conn.post '/b/battle', { chk: chk, friend: 'qpq' } # punch trooper
          success = true
        rescue
          puts "errors. retrying in #{RETRY_SEC} sec"
          sleep RETRY_SEC
        end
      end
    end

    # Check if can go to Raids
    raid_index = 1
    while hq_page.scan(/b\/raid\?/).size > 0
      # Perform Raids
      sleep(SLEEP)
      log "Raid #{raid_index}"

      success = false
      while !success
        begin
          conn.get "b/raid?chk=#{chk}"
          success = true
        rescue
          puts "errors. retrying in #{RETRY_SEC} sec"
          sleep RETRY_SEC
        end
      end

      raid_index += 1

      sleep(SLEEP)

      success = false
      while !success
        begin
          hq_page = conn.get('/hq').body
          success = true
        rescue
          puts "errors. retrying in #{RETRY_SEC} sec"
          sleep RETRY_SEC
        end
      end
    end
  end

  # Check if can upgrade
  log 'Checking if can upgrade'
  sleep(SLEEP)

  success = false
  while !success
    begin
      upgrade_page = conn.get('/t/0').body
      success = true
    rescue
      puts "errors. retrying in #{RETRY_SEC} sec"
      sleep RETRY_SEC
    end
  end

  upgrade_cost = upgrade_page.scan(/Upgrade\s+for\s+([0-9]+)/).flatten.first.to_i
  have_money = upgrade_page.scan(/([0-9]+)\s+<\/div>\s+<div\s+class="power/).flatten.first.to_i
  log "Has #{had_money}->#{have_money} money, need #{upgrade_cost} for next upgrade"
  can_upgrade = upgrade_cost <= have_money && have_money > 0
  @total_money += (have_money - had_money)

  if can_upgrade
    log "Can upgrade http://#{trooper_name}.minitroopers.com/t/0"
    @can_upgrade_troopers << trooper_name

    if TRY_UPGRADE
      chk_arr = upgrade_page.scan(/levelup=([a-zA-Z0-9]+)/).flatten
      chk = chk_arr.size > 0 ? chk_arr.first : nil
      log chk ? "chk=#{chk}" : 'Could not find chk!'

      if chk
        # Initialize levelup page
        sleep(SLEEP)

        success = false
        while !success
          begin
            conn.get("t/0?levelup=#{chk}").body
            success = true
          rescue
            puts "errors. retrying in #{RETRY_SEC} sec"
            sleep RETRY_SEC
          end
        end

        # Load levelup page
        sleep(SLEEP)

        success = false
        while !success
          begin
            levelup_page = conn.get('/levelup/0').body
            success = true
          rescue
            puts "errors. retrying in #{RETRY_SEC} sec"
            sleep RETRY_SEC
          end
        end

        available_skills = levelup_page.scan(/\/levelup\/0\?skill=(\d+)\&/).flatten.collect { |s| s.to_i }
        log "Skills to upgrade: #{available_skills}"

        sleep(SLEEP)
        chk_arr = levelup_page.scan(/skill=[^c]+chk=([a-zA-Z0-9]+)/).flatten
        chk = chk_arr.size > 0 ? chk_arr.first : nil
        log chk ? "chk=#{chk}" : 'Could not find chk!'

        #TODO: pick best skill, and upgrade
        #conn.get("/levelup/0?skill=106&amp;chk=#{chk}").body
      end
    end
  end

  log '-'
  sleep(SLEEP)
end

if @can_upgrade_troopers.size > 0
  log 'Upgrade:'
  @can_upgrade_troopers.each_with_index do |trooper_name, index|
    log "http://#{trooper_name}.minitroopers.com/t/0"
    log '' if index % 20 == 0 && index != 0
  end
end

log "Total money earned: #{@total_money}"

@log_file.close
