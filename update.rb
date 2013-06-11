require 'faraday'
require 'faraday-cookie_jar'
require 'debugger'

TROOPERS = YAML::load(File.open('troopers.yml'))

SLEEP = 4
DEBUG = false
@can_upgrade_troopers = []
@log_file = File.open("#{Time.now.strftime('%d-%b_%H-%M-%S')}_minitroopers.log", 'w')

def log(str)
  @log_file.write("#{str}\r\n")
  puts str
end

TROOPERS['troopers'].each do |trooper_name|
  sleep(SLEEP)
  log "Working on #{trooper_name} #{TROOPERS['troopers'].index(trooper_name)} of #{TROOPERS['troopers'].count}"
  conn = Faraday.new(url: "http://#{trooper_name}.minitroopers.com") do |faraday|
    faraday.request :url_encoded # form-encode POST params
    faraday.response :logger if DEBUG
    faraday.use :cookie_jar
    faraday.adapter Faraday.default_adapter
  end
  hq_page = conn.get('/hq').body

  # Find current money
  had_money = hq_page.scan(/([0-9]+)\s+<\/div>\s+<div\s+class="power/).flatten.first.to_i

  # Find chk
  chk_arr = hq_page.scan(/miss[^c]+chk=([a-zA-Z0-9]+)/).flatten
  chk = chk_arr.size > 0 ? chk_arr.first : nil

  log chk ? "chk=#{chk}" : 'Could not find chk!'

  if chk
    # Unlock mission if possible
    sleep(2)
    log 'Unlocking mission'
    conn.get "/unlock?mode=miss;chk=#{chk}"

    # Perform 3 Missions
    # Missions then Fight give better change to Infiltrate mission next time
    # which is better for winning more
    3.times do |index|
      sleep(SLEEP)
      log "Mission #{index}"
      conn.get "b/mission?chk=#{chk}"
    end

    # Perform 3 Fights
    3.times do |index|
      sleep(SLEEP)
      log "Fighting #{index}"
      conn.post '/b/battle', {chk: chk, friend: TROOPERS['punch_troopers'].sample}
    end

    # Check if can go to Raids
    can_raid = (hq_page.scan(/b\/raid\?/).size > 0)
    if can_raid
      # Perform 3 Raids
      3.times do |index|
        sleep(SLEEP)
        log "Raid #{index}"
        conn.get "b/raid?chk=#{chk}"
      end
    end
  end

  sleep(SLEEP)
  # Check if can upgrade
  log 'Checking if can upgrade'
  upgrade_page = conn.get('/t/0').body

  upgrade_cost = upgrade_page.scan(/Upgrade\s+for\s+([0-9]+)/).flatten.first.to_i
  have_money = upgrade_page.scan(/([0-9]+)\s+<\/div>\s+<div\s+class="power/).flatten.first.to_i
  if upgrade_cost <= have_money && have_money > 0
    @can_upgrade_troopers << trooper_name
  end
  log "Has #{had_money}->#{have_money} money, need #{upgrade_cost} for upgrade"

  log '-'
  sleep(SLEEP)
end

if @can_upgrade_troopers.size > 0
  log 'Upgrade:'
  @can_upgrade_troopers.each do |trooper_name|
    log "http://#{trooper_name}.minitroopers.com/hq"
  end
end

@log_file.close
