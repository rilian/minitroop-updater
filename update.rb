require 'faraday'
require 'faraday-cookie_jar'
require 'debugger'

trooper_names = %w[supri2 supri2-1 supril2 supril2-1 supril3 supril3-1 supril4 supril4-1 supril5 supril5-1
  supril6 supril6-1 supril7 supril7-1 supril8-1 supril8 supril8-3 supril9 supril9-1 supril10 supril11 supril12
  supril14 supril15
  super-rilian andreyfenchenko
  rbot1 rbot2 rbot3 rbot4 rbot5 rbot6 rbot7 rbot8 rbot9 rbot10 rbot11 rbot12 rbot13 rbot14 rbot15 rbot16 rbot17
  rbot18 rbot19 rbot20 rbot21 rbot22 rbot23 rbot24 rbot25 rbot26 rbot27 rbot28 rbot29 rbot30 rbot31 rbot32
  rbot33 rbot34 rbot35 rbot36 rbot37 rbot39
]

punch_troopers = %w[
  fenchenko
]

SLEEP = 4
DEBUG = false
@can_upgrade_troopers = []
@log_file = File.open("#{Time.now.strftime('%d-%b_%H-%M-%S')}_minitroopers.log", 'w')

def log(str)
  @log_file.write("#{str}\r\n")
  puts str
end

trooper_names.each do |trooper_name|
  sleep(SLEEP)
  log "Working on #{trooper_name} #{trooper_names.index(trooper_name)} of #{trooper_names.count}"
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
      conn.post '/b/battle', {chk: chk, friend: punch_troopers.sample}
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
