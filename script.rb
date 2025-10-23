#!/usr/bin/env ruby

require 'json'
require 'optparse'

=begin
    Script d'audit système Linux - DACS AUDIT
    Version SSH compatible : permet un audit local ou distant via SSH
=end

# === Options du script ===
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby audit_ssh.rb [options]"
  opts.on("--json FILE", "Export du résultat au format JSON dans FILE") { |file| options[:json] = file }
  opts.on("--remote-host HOST", "Adresse IP ou nom d'hôte distant à auditer") { |host| options[:remote_host] = host }
  opts.on("--remote-user USER", "Nom d'utilisateur SSH (défaut: root)") { |user| options[:remote_user] = user }
  opts.on("--key PATH", "Chemin vers la clé privée SSH") { |key| options[:ssh_key] = key }
end.parse!

# === Méthode d’exécution (locale ou distante) ===
def run_cmd(cmd, options)
  if options[:remote_host]
    user = options[:remote_user] || "root"
    key_part = options[:ssh_key] ? "-i #{options[:ssh_key]}" : ""
    ssh_cmd = "ssh -o StrictHostKeyChecking=no #{key_part} #{user}@#{options[:remote_host]} \"#{cmd}\""
    return `#{ssh_cmd}`.strip
  else
    return `#{cmd}`.strip
  end
end

# === Expressions régulières ===
regex_utilisateur_co = /^([^:]+):[^:]*:(\d+):\d+:[^:]*:[^:]*:[^:]*$/
regex_processus_consommateur_traffic_reseau = /(\S+)\s+\S+\s+\S+\s+([\d.:]+)\s+([\d.:]+)\s+users:\(\("([^"]+)",pid=(\d+)/
regex_processus_consommateurs = /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)$/

# === Collecte des informations ===
nom_machine = run_cmd("hostname", options)
distrib = run_cmd("lsb_release -d 2>/dev/null || cat /etc/*release | head -n 1", options).sub(/^Description:\s*/, '')
v_noyau = run_cmd("uname -r", options)
uptime = run_cmd("uptime -p", options)
loadavg_raw = run_cmd("cat /proc/loadavg", options).split
m_charge = "1 min: #{loadavg_raw[0]}, 5 min: #{loadavg_raw[1]}, 15 min: #{loadavg_raw[2]}"
memoire = run_cmd("free -h", options)
swap_dispo_utilise = run_cmd("free -h | grep -i swap", options)

# === Interfaces réseau ===
interfaces_raw = run_cmd("ls /sys/class/net", options).split
inter_reseau = interfaces_raw.map do |iface|
  next if iface == "lo"
  mac = run_cmd("cat /sys/class/net/#{iface}/address 2>/dev/null", options)
  ip = run_cmd("ip -4 addr show #{iface} | grep inet | awk '{print $2}'", options)
  { interface: iface, mac: mac.empty? ? "N/A" : mac, ip: ip.strip }
end.compact

# === Utilisateurs humains ===
passwd_content = run_cmd("cat /etc/passwd", options).split("\n")
utilisateur_humains = passwd_content.map do |line|
  if line =~ regex_utilisateur_co
    user, uid = $1, $2.to_i
    user if uid >= 1000 && user != "nobody"
  end
end.compact
utilisateurs_co = run_cmd("who", options)

# === Espace disque ===
espaceDisque = run_cmd("df -h", options)

# === Processus ===
processus_consomateurs = []
run_cmd("ps aux --sort=-%cpu | head -n 11", options).lines.drop(1).each do |line|
  if line =~ regex_processus_consommateurs
    user, pid, cpu, mem, cmd = $1, $2, $3, $4, $5
    processus_consomateurs << { user: user, pid: pid, cpu: cpu.to_f, mem: mem.to_f, cmd: cmd }
  end
end

processus_consomateurs_traffic_reseau = []
run_cmd("ss -tunap | head -n 20", options).lines.each do |line|
  if line =~ regex_processus_consommateur_traffic_reseau
    etat, src, dst, proc_name, pid = $1, $2, $3, $4, $5
    processus_consomateurs_traffic_reseau << { etat: etat, source: src, destination: dst, process: proc_name, pid: pid.to_i }
  end
end

# === Statut des services clés ===
services = %w[sshd cron docker apache2 nginx mysql postfix]
status_service_cle = services.map do |srv|
  [srv, run_cmd("systemctl is-active #{srv} 2>/dev/null", options)]
end.to_h

# === Résultats de l’audit ===
audit = {
  "Nom de la machine" => nom_machine,
  "Distribution" => distrib,
  "Version du noyau" => v_noyau,
  "Uptime" => uptime,
  "Charge moyenne" => m_charge,
  "Mémoire" => memoire,
  "Swap" => swap_dispo_utilise,
  "Interfaces réseau" => inter_reseau,
  "Utilisateurs humains (uid ≥1000)" => utilisateur_humains,
  "Utilisateurs connectés" => utilisateurs_co.split("\n"),
  "Espace disque" => espaceDisque,
  "Processus consommateurs CPU/MEM" => processus_consomateurs,
  "Processus consommateurs réseau" => processus_consomateurs_traffic_reseau,
  "Services clés" => status_service_cle
}

# === Export ou affichage ===
if options[:json]
  File.open(options[:json], "w") { |f| f.write(JSON.pretty_generate(audit)) }
  puts "Résultats sauvegardés dans #{options[:json]}"
else


  # Couleurs pour le terminal
  RESET = "\e[0m"
  GRAS = "\e[1m"
  BLEU = "\e[36m"
  GRIS = "\e[90m"
  VERT = "\e[32m"
  ROUGE = "\e[31m"
  JAUNE = "\e[33m"

  # Méthode pour afficher les titres de section dans un format stylisé
  def section_titre(titre)
    puts "\n#{BLEU}#{GRAS}> #{titre}#{RESET}"
    puts "  #{GRIS}#{"─" * 56}#{RESET}"
  end

  # Méthode pour déterminer la couleur du statut d'un service
  def statut_couleur(statut)
    case statut
    when /active|actif/i then VERT
    when /inactive|inactif/i then ROUGE
    else GRIS
    end
  end

  # Affichage du rapport d'audit dans le terminal - style ASCII art
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

  # informations générales
  section_titre("INFORMATIONS GÉNÉRALES")
  puts "  Distribution      : #{distrib}"
  puts "  Version noyau     : #{v_noyau}"
  puts "  Uptime            : #{uptime}"

  # charge moyenne avec code couleur selon la valeur
  charge_values = [loadavg_raw[0].to_f, loadavg_raw[1].to_f, loadavg_raw[2].to_f]
  charge_color = charge_values.max > 4 ? ROUGE : (charge_values.max > 2 ? JAUNE : VERT)
  puts "  Charge moyenne    : #{charge_color}#{m_charge}#{RESET}"

  # Mémoire et Swap avec code couleur selon l'utilisation
  section_titre("MÉMOIRE ET SWAP")
  memoire_lines = memoire.split("\n")

  puts "  #{GRIS}               Total       Utilisé     Disponible#{RESET}"
  puts "  #{GRIS}#{"─" * 56}#{RESET}"

  if memoire_lines[1]
    mem_data = memoire_lines[1].split
    mem_pct = (mem_data[2].to_f / mem_data[1].to_f * 100) rescue 0
    mem_color = mem_pct > 80 ? ROUGE : (mem_pct > 60 ? JAUNE : VERT)
    puts "  #{mem_color}RAM#{RESET}       : #{mem_data[1].rjust(8)}  │  #{mem_data[2].rjust(8)}  │  #{mem_data[6].rjust(10)}"
  end

  if memoire_lines[2]
    swap_data = memoire_lines[2].split
    swap_total = swap_data[1]
    swap_utilise = swap_data[2]
    swap_color = swap_utilise.to_f > 0 ? JAUNE : VERT
    puts "  #{swap_color}Swap#{RESET}      : #{swap_total.rjust(8)}  │  #{swap_utilise.rjust(8)}  │  #{swap_data[3].rjust(10)}"
  end

  # Interfaces réseau, adresses IP et état UP/DOWN
  section_titre("INTERFACES RÉSEAU")
  if inter_reseau.empty?
    puts "  #{GRIS}[Aucune interface réseau détectée]#{RESET}"
  else
    inter_reseau.each do |iface|
      # Récupérer l'état de l'interface (UP/DOWN)
      etat = `cat /sys/class/net/#{iface[:interface]}/operstate 2>/dev/null`.strip.upcase
      etat_color = etat == "UP" ? VERT : ROUGE
      etat_display = etat.empty? ? "UNKNOWN" : etat

      # Statut IP
      ip_status = iface[:ip].empty? ? ROUGE : VERT
      ip_display = iface[:ip].empty? ? 'Non configurée' : iface[:ip]

      puts "  - #{iface[:interface].ljust(10)} #{etat_color}[#{etat_display}]#{RESET}"
      puts "    ├─ MAC  : #{GRIS}#{iface[:mac]}#{RESET}"
      puts "    └─ IPv4 : #{ip_status}#{ip_display}#{RESET}"
      puts ""
    end
  end

  # Utilisateurs humains (uid >= 1000)
  section_titre("UTILISATEURS")
  if utilisateur_humains.empty?
    puts "  #{GRIS}[Aucun utilisateur humain trouvé]#{RESET}"
  else
    utilisateur_humains.each { |u| puts "  - #{u}" }
  end

  # Utilisateurs connectés
  section_titre("UTILISATEURS CONNECTÉS")
  if utilisateurs_co.empty?
    puts "  #{GRIS}[Aucun utilisateur connecté]#{RESET}"
  else
    utilisateurs_co.each_line { |ligne| puts "  #{ligne.chomp}" }
  end

  # Espace disque par partition avec code couleur selon l'utilisation
  section_titre("ESPACE DISQUE PAR PARTITION")
  espaceDisque.each_line.with_index do |ligne, idx|
    if idx == 0
      # En-tête
      puts "  #{ligne.chomp}"
      puts "  #{GRIS}#{"─" * 56}#{RESET}"
    else
      # Extraire le pourcentage d'utilisation
      if ligne =~ /(\d+)%/
        usage = $1.to_i
        color = usage > 80 ? ROUGE : (usage > 60 ? JAUNE : RESET)
        puts "  #{color}#{ligne.chomp}#{RESET}"
      else
        puts "  #{ligne.chomp}"
      end
    end
  end

  # Processus consommateurs de CPU et de mémoire
  section_titre("PROCESSUS CONSOMMATEURS (CPU/MEM)")
  if processus_consomateurs.empty?
    puts "  #{GRIS}[Aucun processus détecté]#{RESET}"
  else
    processus_consomateurs.each do |p|
      cmd = p[:cmd].length > 80 ? p[:cmd][0..77] + "..." : p[:cmd]
      cpu_color = p[:cpu] > 50 ? ROUGE : (p[:cpu] > 20 ? JAUNE : RESET)
      mem_color = p[:mem] > 10 ? ROUGE : (p[:mem] > 5 ? JAUNE : RESET)

      puts "  - #{p[:user].ljust(12)} PID: #{p[:pid].to_s.rjust(6)}  │  CPU: #{cpu_color}#{p[:cpu].to_s.rjust(5)}%#{RESET}  │  MEM: #{mem_color}#{p[:mem].to_s.rjust(5)}%#{RESET}"
      puts "    └─ #{GRIS}#{cmd}#{RESET}"
      puts ""
    end
  end

  # Processus consommateurs de trafic réseau
  section_titre("PROCESSUS CONSOMMATEURS (RÉSEAU)")
  if processus_consomateurs_traffic_reseau.empty?
    puts "  #{GRIS}[Aucun processus consommateur de trafic réseau détecté]#{RESET}"
  else
    processus_consomateurs_traffic_reseau.each do |p|
      etat_color = p[:etat] == "ESTAB" ? VERT : GRIS
      puts "  - #{p[:process].ljust(20)} PID: #{p[:pid].to_s.rjust(6)}  #{etat_color}[#{p[:etat]}]#{RESET}"
      puts "    └─ #{GRIS}#{p[:source]} → #{p[:destination]}#{RESET}"
    end
  end

  # Statut des services clés
  section_titre("SERVICES CLÉS")
  status_service_cle.each do |s, st|
    couleur = statut_couleur(st)
    statut = st.downcase.include?("actif") || st.downcase.include?("active") ? "#{VERT}[OK]#{RESET}" : "#{ROUGE}[--]#{RESET}"
    puts "  #{statut} #{s.ljust(25)} : #{couleur}#{st}#{RESET}"
  end

  puts "\n" + "  " + "═" * 70
  puts "    Audit terminé avec succès, merci de faire confiance à DACS AUDIT"
  puts "  " + "═" * 70 + "\n"
end