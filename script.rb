#!/usr/bin/env ruby


require 'json'

nom_machine = `hostname`.strip
#distrib = `lsb_release -a`.strip 
v_noyau= `uname -r`.strip
# uptime =
#m_charge= `cat /proc/loadavg/`.strip 
#memoire= `free -h`.strip
#swap_dispo_utilise = `free -h | grep -i swap`.strip
# inter_reseau=
# utilisateur_humains=
utilisateurs_co = `who`.strip
espaceDisque = `df -h`.strip

# processus_consomateurs = 
# processus_consomateurs_traffic_reseau =
# status_service_cle = 




puts nom_machine
puts utilisateurs_co
puts espaceDisque