#!/usr/bin/env ruby

require 'json'
require 'optparse'

# Expressions régulières
regex_utilisateur_co = /^([^:]+):[^:]*:(\d+):\d+:[^:]*:[^:]*:[^:]*$/
regex_processus_consommateur_traffic_reseau = /(\S+)\s+\S+\s+\S+\s+([\d.:]+)\s+([\d.:]+)\s+users:\(\("([^"]+)",pid=(\d+)/
regex_processus_consommateurs = /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)$/

# Détection du mode audit (local ou via Docker)
IN_DOCKER = File.exist?("/.dockerenv")
HOST_MODE = ENV['HOST_MODE'] == '1'
BASE_PATH = (IN_DOCKER || HOST_MODE) ? "/host" : ""

# Options de ligne de commande
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby audit.rb [options]"
  opts.on("--json FILE", "Export du résultat au format JSON dans FILE") { |file| options[:json] = file }
end.parse!

# Collecte des informations système
nom_machine = `hostname`.strip
distrib = `lsb_release -d 2>/dev/null || cat #{BASE_PATH}/etc/*release | head -n 1`.strip.sub(/^Description:\s*/, '')
v_noyau = `uname -r`.strip
uptime_seconds = File.read("#{BASE_PATH}/proc/uptime").split[0].to_f rescue 0.0
uptime = (uptime_seconds / 3600).round(2)
loadavg_raw = File.read("#{BASE_PATH}/proc/loadavg").strip.split rescue ["0", "0", "0"]
m_charge = "1 min: #{loadavg_raw[0]}, 5 min: #{loadavg_raw[1]}, 15 min: #{loadavg_raw[2]}"
memoire = `free -h`.strip
swap_dispo_utilise = `free -h | grep -i swap`.strip

# Interfaces réseau
inter_reseau = Dir.children("#{BASE_PATH}/sys/class/net").map do |iface|
  next if iface == "lo"

  mac = File.read("#{BASE_PATH}/sys/class/net/#{iface}/address").strip rescue "N/A"

  ip_data = File.read("#{BASE_PATH}/proc/net/fib_trie") rescue ""
  ip_match = ip_data.scan(/32 host (\d+\.\d+\.\d+\.\d+)/).flatten.find { |addr| !addr.start_with?("127.") }

  { interface: iface, mac: mac, ip: ip_match || "" }
end.compact

# Utilisateurs humains
utilisateur_humains = []
IO.readlines("#{BASE_PATH}/etc/passwd").each do |line|
  if line =~ regex_utilisateur_co
    user, uid = $1, $2.to_i
    utilisateur_humains << user if uid >= 1000
  end
end

# Utilisateurs connectés
utilisateurs_co = `who 2>/dev/null`.strip

# Espace disque
espaceDisque = `df -h`.strip

# Processus consommateurs CPU/MEM
processus_consomateurs = []
`ps aux --sort=-%cpu | head -n 11`.lines.drop(1).each do |line|
  if line =~ regex_processus_consommateurs
    user, pid, cpu, mem, cmd = $1, $2, $3, $4, $5
    processus_consomateurs << { user: user, pid: pid, cpu: cpu.to_f, mem: mem.to_f, cmd: cmd }
  end
end

# Processus consommateurs trafic réseau
processus_consomateurs_traffic_reseau = []
`ss -tunap 2>/dev/null | head -n 20`.lines.each do |line|
  if line =~ regex_processus_consommateur_traffic_reseau
    etat, src, dst, proc_name, pid = $1, $2, $3, $4, $5
    processus_consomateurs_traffic_reseau << { etat: etat, source: src, destination: dst, process: proc_name, pid: pid.to_i }
  end
end

# Services clés
def check_service(service)
  status = `systemctl is-active #{service} 2>/dev/null`.strip
  status.empty? ? "inconnu" : status
end

status_service_cle = {
  "sshd" => check_service("sshd"),
  "cron" => check_service("cron"),
  "docker" => check_service("docker"),
  "apache2" => check_service("apache2"),
  "nginx" => check_service("nginx")
}

# Résultats
audit = {
  "Nom de la machine" => nom_machine,
  "Distribution" => distrib,
  "Version du noyau" => v_noyau,
  "Uptime (heures)" => uptime,
  "Charge moyenne" => m_charge,
  "Mémoire" => memoire,
  "Swap" => swap_dispo_utilise,
  "Interfaces réseau" => inter_reseau,
  "Utilisateurs humains (uid ⩾1000)" => utilisateur_humains,
  "Utilisateurs connectés" => utilisateurs_co.split("\n"),
  "Espace disque" => espaceDisque,
  "Processus les plus consommateurs de CPU et de mémoire" => processus_consomateurs,
  "Processus les plus consommateurs de trafic réseau" => processus_consomateurs_traffic_reseau,
  "Présence et statut de certains services clés" => status_service_cle
}

# Export JSON
if options[:json]
  File.open(options[:json], "w") { |f| f.write(JSON.pretty_generate(audit)) }
  puts "Résultats sauvegardés dans #{options[:json]}"
  exit
end

# Couleurs
RESET = "\e[0m"
GRAS = "\e[1m"
BLEU = "\e[36m"
GRIS = "\e[90m"
VERT = "\e[32m"
ROUGE = "\e[31m"
JAUNE = "\e[33m"

def section_titre(titre)
  puts "\n#{BLEU}#{GRAS}> #{titre}#{RESET}"
  puts "  #{GRIS}#{"─" * 56}#{RESET}"
end

def statut_couleur(statut)
  case statut
  when /active|actif/i then VERT
  when /inactive|inactif/i then ROUGE
  else GRIS
  end
end

# Affichage
puts "\n"
puts "  ██████╗  █████╗  ██████╗███████╗"
puts "  ██╔══██╗██╔══██╗██╔════╝██╔════╝"
puts "  ██║  ██║███████║██║     ███████╗"
puts "  ██║  ██║██╔══██║██║     ╚════██║"
puts "  ██████╔╝██║  ██║╚██████╗███████║"
puts "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝"
puts ""
puts "  " + "─" * 58
puts "       DACS AUDIT - SYSTÈME LINUX"
puts "       #{nom_machine.upcase} - #{Time.now.strftime('%d %B %Y')}"
puts "  " + "─" * 58
puts "\n"

section_titre("INFORMATIONS GÉNÉRALES")
puts "  Distribution      : #{distrib}"
puts "  Version noyau     : #{v_noyau}"
puts "  Uptime (heures)   : #{uptime}"
charge_values = [loadavg_raw[0].to_f, loadavg_raw[1].to_f, loadavg_raw[2].to_f]
charge_color = charge_values.max > 4 ? ROUGE : (charge_values.max > 2 ? JAUNE : VERT)
puts "  Charge moyenne    : #{charge_color}#{m_charge}#{RESET}"

section_titre("MÉMOIRE ET SWAP")
memoire_lines = memoire.split("\n")
puts "  #{GRIS}               Total       Utilisé     Disponible#{RESET}"
puts "  #{GRIS}#{"─" * 56}#{RESET}"
if memoire_lines[1]
  mem_data = memoire_lines[1].split
  puts "  RAM       : #{mem_data[1].rjust(8)}  │ #{mem_data[2].rjust(8)}  │ #{mem_data[6].rjust(10)}"
end
if memoire_lines[2]
  swap_data = memoire_lines[2].split
  puts "  Swap      : #{swap_data[1].rjust(8)}  │ #{swap_data[2].rjust(8)}  │ #{swap_data[3].rjust(10)}"
end

section_titre("INTERFACES RÉSEAU")
if inter_reseau.empty?
  puts "  #{GRIS}[Aucune interface réseau détectée]#{RESET}"
else
  inter_reseau.each do |iface|
    ip_status = iface[:ip].empty? ? ROUGE : VERT
    puts "  - #{iface[:interface].ljust(10)} │ MAC: #{iface[:mac]} │ IP: #{ip_status}#{iface[:ip].empty? ? 'Non configurée' : iface[:ip]}#{RESET}"
  end
end

section_titre("UTILISATEURS HUMAINS (UID >= 1000)")
utilisateur_humains.each { |u| puts "  - #{u}" }

section_titre("UTILISATEURS CONNECTÉS")
utilisateurs_co.each_line { |ligne| puts "  #{ligne.chomp}" }

section_titre("ESPACE DISQUE PAR PARTITION")
espaceDisque.each_line do |ligne|
  if ligne =~ /(\d+)%/
    usage = $1.to_i
    color = usage > 80 ? ROUGE : (usage > 60 ? JAUNE : RESET)
    puts "  #{color}#{ligne.chomp}#{RESET}"
  else
    puts "  #{ligne.chomp}"
  end
end

section_titre("PROCESSUS CONSOMMATEURS (CPU/MEM)")
processus_consomateurs.each do |p|
  cmd = p[:cmd].length > 80 ? p[:cmd][0..77] + "..." : p[:cmd]
  cpu_color = p[:cpu] > 50 ? ROUGE : (p[:cpu] > 20 ? JAUNE : RESET)
  mem_color = p[:mem] > 10 ? ROUGE : (p[:mem] > 5 ? JAUNE : RESET)
  puts "  - #{p[:user].ljust(12)} PID: #{p[:pid].to_s.rjust(6)} │ CPU: #{cpu_color}#{p[:cpu]}%#{RESET} │ MEM: #{mem_color}#{p[:mem]}%#{RESET}"
  puts "    └─ #{GRIS}#{cmd}#{RESET}"
end

section_titre("PROCESSUS CONSOMMATEURS (RÉSEAU)")
processus_consomateurs_traffic_reseau.each do |p|
  etat_color = p[:etat] == "ESTAB" ? VERT : GRIS
  puts "  - #{p[:process].ljust(20)} PID: #{p[:pid].to_s.rjust(6)} #{etat_color}[#{p[:etat]}]#{RESET}"
  puts "    └─ #{GRIS}#{p[:source]} → #{p[:destination]}#{RESET}"
end

section_titre("SERVICES CLÉS")
status_service_cle.each do |s, st|
  couleur = statut_couleur(st)
  statut = st.downcase.include?("actif") || st.downcase.include?("active") ? "#{VERT}[OK]#{RESET}" : "#{ROUGE}[--]#{RESET}"
  puts "  #{statut} #{s.ljust(25)} : #{couleur}#{st}#{RESET}"
end

puts "\n" + "  " + "═" * 70
puts "    Audit terminé avec succès, merci de faire confiance à DACS AUDIT"
puts "  " + "═" * 70 + "\n"