#!/usr/bin/env ruby

require 'json'
require 'optparse'

=begin
    Script d'audit système Linux - DACS AUDIT
    Version compatible Prometheus : mode agent avec endpoint /metrics
=end

# === Options du script ===
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script.rb [options]"
  opts.on("--json FILE", "Export du résultat au format JSON dans FILE") { |file| options[:json] = file }
  opts.on("--remote-host HOST", "Adresse IP ou nom d'hôte distant à auditer") { |host| options[:remote_host] = host }
  opts.on("--remote-user USER", "Nom d'utilisateur SSH (défaut: root)") { |user| options[:remote_user] = user }
  opts.on("--key PATH", "Chemin vers la clé privée SSH") { |key| options[:ssh_key] = key }
  opts.on("--agent", "Démarrer le mode agent Prometheus (expose /metrics)") { options[:agent] = true }
end.parse!

# === Méthode d'exécution (locale ou distante) ===
def run_cmd(cmd, options = {})
  if options[:remote_host]
    user = options[:remote_user] || "root"
    key_part = options[:ssh_key] ? "-i #{options[:ssh_key]}" : ""
    ssh_cmd = "ssh -o StrictHostKeyChecking=no #{key_part} #{user}@#{options[:remote_host]} \"#{cmd}\""
    return `#{ssh_cmd}`.strip
  else
    return `#{cmd}`.strip
  end
end

# === MODE AGENT PROMETHEUS ===
if options[:agent]
  require 'sinatra'
  require 'sinatra/base'

  class MetricsApp < Sinatra::Base
    set :bind, '0.0.0.0'
    set :port, 4567
    disable :protection
    set :environment, :production

    get '/metrics' do
      content_type 'text/plain; charset=utf-8'

      metrics = []
      
      # === LOAD AVERAGE ===
      begin
        loadavg_raw = `cat /proc/loadavg`.strip.split
        metrics << "# HELP load_average_1min Load average over 1 minute"
        metrics << "# TYPE load_average_1min gauge"
        metrics << "load_average_1min #{loadavg_raw[0]}"
        
        metrics << "# HELP load_average_5min Load average over 5 minutes"
        metrics << "# TYPE load_average_5min gauge"
        metrics << "load_average_5min #{loadavg_raw[1]}"
        
        metrics << "# HELP load_average_15min Load average over 15 minutes"
        metrics << "# TYPE load_average_15min gauge"
        metrics << "load_average_15min #{loadavg_raw[2]}"
      rescue => e
        STDERR.puts "Error collecting load average: #{e.message}"
      end

      # === UPTIME ===
      begin
        uptime = `awk '{print $1}' /proc/uptime`.strip.to_f
        metrics << "# HELP uptime_seconds System uptime in seconds"
        metrics << "# TYPE uptime_seconds counter"
        metrics << "uptime_seconds #{uptime}"
      rescue => e
        STDERR.puts "Error collecting uptime: #{e.message}"
      end

      # === MEMORY ===
      begin
        meminfo = {}
        File.readlines('/proc/meminfo').each do |line|
          if line =~ /^(\w+):\s+(\d+)/
            meminfo[$1] = $2.to_i * 1024 # Convertir en bytes
          end
        end
        
        mem_total = meminfo['MemTotal'] || 0
        mem_available = meminfo['MemAvailable'] || 0
        mem_used = mem_total - mem_available
        mem_usage_percent = mem_total > 0 ? (mem_used.to_f / mem_total * 100) : 0
        
        metrics << "# HELP memory_total_bytes Total memory in bytes"
        metrics << "# TYPE memory_total_bytes gauge"
        metrics << "memory_total_bytes #{mem_total}"
        
        metrics << "# HELP memory_used_bytes Used memory in bytes"
        metrics << "# TYPE memory_used_bytes gauge"
        metrics << "memory_used_bytes #{mem_used}"
        
        metrics << "# HELP memory_available_bytes Available memory in bytes"
        metrics << "# TYPE memory_available_bytes gauge"
        metrics << "memory_available_bytes #{mem_available}"
        
        metrics << "# HELP memory_usage_percent Memory usage percentage"
        metrics << "# TYPE memory_usage_percent gauge"
        metrics << "memory_usage_percent #{mem_usage_percent.round(2)}"
      rescue => e
        STDERR.puts "Error collecting memory: #{e.message}"
      end

      # === SWAP ===
      begin
        swap_total = meminfo['SwapTotal'] || 0
        swap_free = meminfo['SwapFree'] || 0
        swap_used = swap_total - swap_free
        
        metrics << "# HELP swap_total_bytes Total swap in bytes"
        metrics << "# TYPE swap_total_bytes gauge"
        metrics << "swap_total_bytes #{swap_total}"
        
        metrics << "# HELP swap_used_bytes Used swap in bytes"
        metrics << "# TYPE swap_used_bytes gauge"
        metrics << "swap_used_bytes #{swap_used}"
      rescue => e
        STDERR.puts "Error collecting swap: #{e.message}"
      end

      # === CPU ===
      begin
        cpu_stat = `cat /proc/stat | grep '^cpu '`.strip.split
        cpu_total = cpu_stat[1..].map(&:to_i).sum
        cpu_idle = cpu_stat[4].to_i
        cpu_usage = cpu_total > 0 ? ((cpu_total - cpu_idle).to_f / cpu_total * 100) : 0
        
        metrics << "# HELP cpu_usage_percent CPU usage percentage"
        metrics << "# TYPE cpu_usage_percent gauge"
        metrics << "cpu_usage_percent #{cpu_usage.round(2)}"
      rescue => e
        STDERR.puts "Error collecting CPU: #{e.message}"
      end

      # === DISK USAGE ===
      begin
        df_output = `df -B1 /`.strip.split("\n")[1]
        if df_output
          parts = df_output.split
          disk_total = parts[1].to_i
          disk_used = parts[2].to_i
          disk_available = parts[3].to_i
          disk_usage_percent = parts[4].to_s.gsub('%', '').to_f
          
          metrics << "# HELP disk_total_bytes Total disk space in bytes"
          metrics << "# TYPE disk_total_bytes gauge"
          metrics << "disk_total_bytes #{disk_total}"
          
          metrics << "# HELP disk_used_bytes Used disk space in bytes"
          metrics << "# TYPE disk_used_bytes gauge"
          metrics << "disk_used_bytes #{disk_used}"
          
          metrics << "# HELP disk_available_bytes Available disk space in bytes"
          metrics << "# TYPE disk_available_bytes gauge"
          metrics << "disk_available_bytes #{disk_available}"
          
          metrics << "# HELP disk_usage_percent Disk usage percentage"
          metrics << "# TYPE disk_usage_percent gauge"
          metrics << "disk_usage_percent #{disk_usage_percent}"
        end
      rescue => e
        STDERR.puts "Error collecting disk: #{e.message}"
      end

      # === SERVICES STATUS ===
      begin
        services = %w[sshd cron docker apache2 nginx mysql postfix]
        metrics << "# HELP service_status Service status (1=active, 0=inactive)"
        metrics << "# TYPE service_status gauge"
        
        services.each do |srv|
          status = `systemctl is-active #{srv} 2>/dev/null`.strip
          value = status == "active" ? 1 : 0
          metrics << "service_status{service=\"#{srv}\"} #{value}"
        end
      rescue => e
        STDERR.puts "Error collecting services: #{e.message}"
      end

      # === NETWORK CONNECTIONS ===
      begin
        tcp_connections = `ss -tan | grep ESTAB | wc -l`.strip.to_i
        metrics << "# HELP tcp_connections_total Total established TCP connections"
        metrics << "# TYPE tcp_connections_total gauge"
        metrics << "tcp_connections_total #{tcp_connections}"
      rescue => e
        STDERR.puts "Error collecting network: #{e.message}"
      end

      # === PROCESSES ===
      begin
        total_processes = `ps aux | wc -l`.strip.to_i - 1
        metrics << "# HELP processes_total Total number of processes"
        metrics << "# TYPE processes_total gauge"
        metrics << "processes_total #{total_processes}"
      rescue => e
        STDERR.puts "Error collecting processes: #{e.message}"
      end

      metrics.join("\n") + "\n"
    end

    get '/health' do
      content_type 'application/json'
      { status: 'healthy', timestamp: Time.now.to_i }.to_json
    end
  end

  puts "🚀 Agent Prometheus démarré sur http://0.0.0.0:4567"
  puts "📊 Métriques disponibles sur http://0.0.0.0:4567/metrics"
  MetricsApp.run!
  exit 0
end

# === MODE AUDIT NORMAL (reste de votre code existant) ===
regex_utilisateur_co = /^([^:]+):[^:]*:(\d+):\d+:[^:]*:[^:]*:[^:]*$/
regex_processus_consommateur_traffic_reseau = /(\S+)\s+\S+\s+\S+\s+([\d.:]+)\s+([\d.:]+)\s+users:\(\("([^"]+)",pid=(\d+)/
regex_processus_consommateurs = /^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)$/

nom_machine = run_cmd("hostname", options)
distrib = run_cmd("lsb_release -d 2>/dev/null || cat /etc/*release | head -n 1", options).sub(/^Description:\s*/, '')
v_noyau = run_cmd("uname -r", options)
uptime = run_cmd("uptime -p", options)
loadavg_raw = run_cmd("cat /proc/loadavg", options).split
m_charge = "1 min: #{loadavg_raw[0]}, 5 min: #{loadavg_raw[1]}, 15 min: #{loadavg_raw[2]}"
memoire = run_cmd("free -h", options)
swap_dispo_utilise = run_cmd("free -h | grep -i swap", options)

interfaces_raw = run_cmd("ls /sys/class/net", options).split
inter_reseau = interfaces_raw.map do |iface|
  next if iface == "lo"
  mac = run_cmd("cat /sys/class/net/#{iface}/address 2>/dev/null", options)
  ip = run_cmd("ip -4 addr show #{iface} | grep inet | awk '{print $2}'", options)
  { interface: iface, mac: mac.empty? ? "N/A" : mac, ip: ip.strip }
end.compact

passwd_content = run_cmd("cat /etc/passwd", options).split("\n")
utilisateur_humains = passwd_content.map do |line|
  if line =~ regex_utilisateur_co
    user, uid = $1, $2.to_i
    user if uid >= 1000 && user != "nobody"
  end
end.compact
utilisateurs_co = run_cmd("who", options)

espaceDisque = run_cmd("df -h", options)

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

services = %w[sshd cron docker apache2 nginx mysql postfix]
status_service_cle = services.map do |srv|
  [srv, run_cmd("systemctl is-active #{srv} 2>/dev/null", options)]
end.to_h

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

if options[:json]
  File.open(options[:json], "w") { |f| f.write(JSON.pretty_generate(audit)) }
  puts "Résultats sauvegardés dans #{options[:json]}"
else
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

  puts "\n  ██████╗  █████╗  ██████╗███████╗"
  puts "  ██╔══██╗██╔══██╗██╔════╝██╔════╝"
  puts "  ██║  ██║███████║██║     ███████╗"
  puts "  ██║  ██║██╔══██║██║     ╚════██║"
  puts "  ██████╔╝██║  ██║╚██████╗███████║"
  puts "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝\n"
  puts "  " + "─" * 58
  puts "       DACS AUDIT - SYSTÈME LINUX"
  puts "       #{nom_machine.upcase} - #{Time.now.strftime('%d %B %Y')}"
  puts "  " + "─" * 58 + "\n"

  section_titre("INFORMATIONS GÉNÉRALES")
  puts "  Distribution      : #{distrib}"
  puts "  Version noyau     : #{v_noyau}"
  puts "  Uptime            : #{uptime}"
  
  charge_values = [loadavg_raw[0].to_f, loadavg_raw[1].to_f, loadavg_raw[2].to_f]
  charge_color = charge_values.max > 4 ? ROUGE : (charge_values.max > 2 ? JAUNE : VERT)
  puts "  Charge moyenne    : #{charge_color}#{m_charge}#{RESET}"

  section_titre("SERVICES CLÉS")
  status_service_cle.each do |s, st|
    couleur = statut_couleur(st)
    statut = st.downcase.include?("actif") || st.downcase.include?("active") ? "#{VERT}[OK]#{RESET}" : "#{ROUGE}[--]#{RESET}"
    puts "  #{statut} #{s.ljust(25)} : #{couleur}#{st}#{RESET}"
  end

  puts "\n  " + "═" * 70
  puts "    Audit terminé avec succès"
  puts "  " + "═" * 70 + "\n"
end