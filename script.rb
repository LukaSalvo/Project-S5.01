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

# Processus consommateurs de CPU et de mémoire
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
  "sshd" => `systemctl is-active sshd 2>/dev/null`.strip,
  "cron" => `systemctl is-active cron 2>/dev/null`.strip,
  "docker" => `systemctl is-active docker 2>/dev/null`.strip,
  "apache2" => `systemctl is-active apache2 2>/dev/null`.strip,
  "nginx" => `systemctl is-active nginx 2>/dev/null`.strip
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

  # Couleurs pour le terminal
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
  puts "  Uptime            : #{uptime}"

  # Coloration de la charge selon le seuil
  charge_values = [loadavg_raw[0].to_f, loadavg_raw[1].to_f, loadavg_raw[2].to_f]
  charge_color = charge_values.max > 4 ? ROUGE : (charge_values.max > 2 ? JAUNE : VERT)
  puts "  Charge moyenne    : #{charge_color}#{m_charge}#{RESET}"

  section_titre("MÉMOIRE ET SWAP")
  memoire_lines = memoire.split("\n")

  # Afficher l'en-tête simplifié
  puts "  #{GRIS}               Total       Utilisé     Disponible#{RESET}"
  puts "  #{GRIS}#{"─" * 56}#{RESET}"

  # Afficher Mémoire RAM
  if memoire_lines[1]
    mem_data = memoire_lines[1].split
    mem_pct = (mem_data[2].to_f / mem_data[1].to_f * 100) rescue 0
    mem_color = mem_pct > 80 ? ROUGE : (mem_pct > 60 ? JAUNE : VERT)
    puts "  #{mem_color}RAM#{RESET}       : #{mem_data[1].rjust(8)}  │  #{mem_data[2].rjust(8)}  │  #{mem_data[6].rjust(10)}"
  end

  # Afficher Swap
  if memoire_lines[2]
    swap_data = memoire_lines[2].split
    swap_total = swap_data[1]
    swap_utilise = swap_data[2]
    swap_color = swap_utilise.to_f > 0 ? JAUNE : VERT
    puts "  #{swap_color}Swap#{RESET}      : #{swap_total.rjust(8)}  │  #{swap_utilise.rjust(8)}  │  #{swap_data[3].rjust(10)}"
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
  if utilisateur_humains.empty?
    puts "  #{GRIS}[Aucun utilisateur humain trouvé]#{RESET}"
  else
    utilisateur_humains.each { |u| puts "  - #{u}" }
  end

  section_titre("UTILISATEURS CONNECTÉS")
  if utilisateurs_co.empty?
    puts "  #{GRIS}[Aucun utilisateur connecté]#{RESET}"
  else
    utilisateurs_co.each_line { |ligne| puts "  #{ligne.chomp}" }
  end

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