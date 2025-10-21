#!/usr/bin/env ruby


require 'json'
require 'optparse'

regex_utilisateur_co =  /^([^:]+):[^:]*:(\d+):\d+:[^:]*:[^:]*:[^:]*$/
regex_processus_consommateur_traffic_reseau = /(\S+)\s+\S+\s+\S+\s+([\d.:]+)\s+([\d.:]+)\s+users:\(\("([^"]+)",pid=(\d+)/
regex_processus_consommateurs = /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)$/


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby audit.rb [options]"
  opts.on("--json FILE", "Export du résultat au format JSON dans FILE") { |file| options[:json] = file }
end.parse!

nom_machine = `hostname`.strip
distrib = `lsb_release -d 2>/dev/null || cat /etc/*release | head -n 1`.strip.sub(/^Description:\s*/, '')
v_noyau = `uname -r`.strip
uptime = `uptime -p`.strip
m_charge = `cat /proc/loadavg`.strip
memoire = `free -h`.strip
swap_dispo_utilise = `free -h | grep -i swap`.strip


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

espaceDisque = `df -h`.strip
processus_consomateurs = []
`ps aux --sort=-%cpu | head -n 11`.lines.drop(1).each do |line|
  if line =~ regex_processus_consommateurs
    user, pid, cpu, mem, cmd = $1, $2, $3, $4, $5
    processus_consomateurs << { user: user, pid: pid, cpu: cpu.to_f, mem: mem.to_f, cmd: cmd }
  end
end

processus_consomateurs_traffic_reseau = []
`ss -tunap | head -n 20`.lines.each do |line|
  if line =~ regex_processus_consommateur_traffic_reseau
    etat, src, dst, proc_name, pid = $1, $2, $3, $4, $5
    processus_consomateurs_traffic_reseau << { etat: etat, source: src, destination: dst, process: proc_name, pid: pid.to_i }
  end
end


status_service_cle = {
  "sshd" => `systemctl is-active sshd`.strip,
  "cron" => `systemctl is-active cron`.strip,
  "docker" => `systemctl is-active docker`.strip
}

audit = {
  "Nom de la machine" => nom_machine,
  "Distribution" => distrib,
  "Version du noyau" => v_noyau,
  "Uptime" => uptime,
  "Charge moyenne" => m_charge,
  "Mémoire" => memoire,
  "Swap" => swap_dispo_utilise,
  "Interfaces réseau" => inter_reseau,
  "Utilisateurs humains (UID >= 1000)" => utilisateur_humains,
  "Utilisateurs connectés" => utilisateurs_co.split("\n"),
  "Espace disque" => espaceDisque,
  "Processus consommateurs" => processus_consomateurs,
  "Processus trafic réseau" => processus_consomateurs_traffic_reseau,
  "Statut services clés" => status_service_cle
}


if options[:json]
  File.open(options[:json], "w") do |f|
    f.write(JSON.pretty_generate(audit))
  end
  puts "Résultats sauvegardés dans #{options[:json]}"
else
  puts "=== AUDIT SYSTÈME - #{nom_machine} ===\n\n"
  puts "→ Distribution : #{distrib}"
  puts "→ Version du noyau : #{v_noyau}"
  puts "→ Uptime : #{uptime}"
  puts "→ Charge moyenne : #{m_charge}\n\n"

  puts "=== Interfaces réseau ==="
  inter_reseau.each do |iface|
    puts "• #{iface[:interface]}  (MAC: #{iface[:mac]}, IP: #{iface[:ip]})"
  end

  puts "\n=== Utilisateurs humains ==="
  utilisateur_humains.each { |u| puts "• #{u}" }

  puts "\n=== Utilisateurs connectés ==="
  puts utilisateurs_co.empty? ? "Aucun utilisateur connecté" : utilisateurs_co

  puts "\n=== Espace disque ==="
  puts espaceDisque

  puts "\n=== Top 10 processus (CPU) ==="
  processus_consomateurs.each do |p|
    puts "• #{p[:user]} (PID #{p[:pid]}) - CPU: #{p[:cpu]}%, MEM: #{p[:mem]}%, CMD: #{p[:cmd]}"
  end

  puts "\n=== Processus consommateurs de trafic réseau ==="
  processus_consomateurs_traffic_reseau.each do |p|
    puts "• #{p[:process]} (PID #{p[:pid]}) [#{p[:etat]}] #{p[:source]} → #{p[:destination]}"
  end

  puts "\n=== Services clés ==="
  status_service_cle.each { |s, st| puts "• #{s} : #{st}" }
end