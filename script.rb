#!/usr/bin/env ruby

require 'json'
require 'optparse'

# Expressions régulières
regex_utilisateur_co =  /^([^:]+):[^:]*:(\d+):\d+:[^:]*:[^:]*:[^:]*$/
regex_processus_consommateur_traffic_reseau = /(\S+)\s+\S+\s+\S+\s+([\d.:]+)\s+([\d.:]+)\s+users:\(\("([^"]+)",pid=(\d+)/
regex_processus_consommateurs = /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)$/

# Options de ligne de commande
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby audit.rb [options]"
  opts.on("--json FILE", "Export du résultat au format JSON dans FILE") { |file| options[:json] = file }
end.parse!

# Liste des commandes systemes collecte des informations
nom_machine = `hostname`.strip
distrib = `lsb_release -d 2>/dev/null || cat /etc/*release | head -n 1`.strip.sub(/^Description:\s*/, '')
v_noyau = `uname -r`.strip
uptime = `uptime -p`.strip
loadavg_raw = `cat /proc/loadavg`.strip.split
m_charge = "1 min: #{loadavg_raw[0]}, 5 min: #{loadavg_raw[1]}, 15 min: #{loadavg_raw[2]}"
memoire = `free -h`.strip
swap_dispo_utilise = `free -h | grep -i swap`.strip

# Informations réseau et utilisateurs
inter_reseau = Dir.children("/sys/class/net").map do |iface|
  next if iface == "lo"
  mac = File.read("/sys/class/net/#{iface}/address").strip rescue "N/A"
  ip = `ip -4 addr show #{iface} | grep inet | awk '{print $2}'`.strip
  { interface: iface, mac: mac, ip: ip }
end.compact
utilisateurs_co = `who`.strip
utilisateur_humains = []
IO.readlines("/etc/passwd").each do |line|
  if line =~ regex_utilisateur_co
    user, uid = $1, $2.to_i
    utilisateur_humains << user if uid >= 1000
  end
end

# Espace disque et processus
espaceDisque = `df -h`.strip
processus_consomateurs = []
`ps aux --sort=-%cpu | head -n 11`.lines.drop(1).each do |line|
  if line =~ regex_processus_consommateurs
    user, pid, cpu, mem, cmd = $1, $2, $3, $4, $5
    processus_consomateurs << { user: user, pid: pid, cpu: cpu.to_f, mem: mem.to_f, cmd: cmd }
  end
end

# Processus consommateurs de trafic réseau
processus_consomateurs_traffic_reseau = []
`ss -tunap | head -n 20`.lines.each do |line|
  if line =~ regex_processus_consommateur_traffic_reseau
    etat, src, dst, proc_name, pid = $1, $2, $3, $4, $5
    processus_consomateurs_traffic_reseau << { etat: etat, source: src, destination: dst, process: proc_name, pid: pid.to_i }
  end
end

# Statut des services clés
status_service_cle = {
  "sshd" => `systemctl is-active sshd`.strip,
  "cron" => `systemctl is-active cron`.strip,
  "docker" => `systemctl is-active docker`.strip
}

# liste des résultats de l'audit
audit = {
  "Nom de la machine" => nom_machine,
  "Distribution" => distrib,
  "Version du noyau" => v_noyau,
  "Uptime" => uptime,
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

# Export ou affichage des résultats dans le json ou dans le terminal
if options[:json]
  File.open(options[:json], "w") do |f|
    f.write(JSON.pretty_generate(audit))
  end
  puts "Résultats sauvegardés dans #{options[:json]}"
else

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

  def section_titre(titre)
    puts "\n> #{titre}"
    puts "  " + "─" * 56
  end

  section_titre("INFORMATIONS GÉNÉRALES")
  puts "  Distribution      : #{distrib}"
  puts "  Version noyau     : #{v_noyau}"
  puts "  Uptime            : #{uptime}"
  puts "  Charge moyenne    : #{m_charge}"

  section_titre("INTERFACES RÉSEAU")
  inter_reseau.each do |iface|
    puts "  - #{iface[:interface].ljust(15)} MAC: #{iface[:mac].ljust(17)}  IP: #{iface[:ip]}"
  end

  section_titre("UTILISATEURS HUMAINS (UID >= 1000)")
  utilisateur_humains.each { |u| puts "  - #{u}" }

  section_titre("UTILISATEURS CONNECTÉS")
  if utilisateurs_co.empty?
    puts "  [Aucun utilisateur connecté]"
  else
    utilisateurs_co.each_line { |ligne| puts "  #{ligne.chomp}" }
  end

  section_titre("ESPACE DISQUE PAR PARTITION")
  espaceDisque.each_line { |ligne| puts "  #{ligne.chomp}" }

  section_titre("PROCESSUS CONSOMMATEURS (CPU/MEM)")
  processus_consomateurs.each do |p|
    puts "  - #{p[:user].ljust(10)} PID:#{p[:pid].to_s.ljust(6)} CPU:#{p[:cpu]}%  MEM:#{p[:mem]}%"
    puts "    #{p[:cmd]}"
  end

  section_titre("PROCESSUS CONSOMMATEURS (RÉSEAU)")
  processus_consomateurs_traffic_reseau.each do |p|
    puts "  - #{p[:process].ljust(20)} PID:#{p[:pid].to_s.ljust(6)} [#{p[:etat]}]"
    puts "    #{p[:source]} → #{p[:destination]}"
  end

  section_titre("SERVICES CLÉS")
  status_service_cle.each do |s, st|
    statut = st.downcase.include?("actif") || st.downcase.include?("active") ? "[OK]" : "[--]"
    puts "  #{statut} #{s.ljust(25)} : #{st}"
  end

  puts "\n" + "  " + "═" * 58
  puts "    Audit terminé avec succès, merci de faire confiance a DACS AUDIT"
  puts "  " + "═" * 58 + "\n"
end