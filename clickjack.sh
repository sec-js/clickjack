#!/bin/bash
NC='\033[0m'
RED='\033[1;38;5;196m'
GREEN='\033[1;38;5;040m'
ORANGE='\033[1;38;5;202m'
BLUE='\033[1;38;5;012m'
BLUE2='\033[1;38;5;032m'
PINK='\033[1;38;5;013m'
GRAY='\033[1;38;5;004m'
NEW='\033[1;38;5;154m'
YELLOW='\033[1;38;5;214m'
CG='\033[1;38;5;087m'
CP='\033[1;38;5;221m'
CPO='\033[1;38;5;205m'
CN='\033[1;38;5;247m'
CNC='\033[1;38;5;051m'
#Coded By Machine404! Don't copy this code without giving me credit~
#https://instagram.com/invisibleclay100
#https://twitter.com/whoami4041
#https://www.youtube.com/channel/UCC_aPnmV_zGfdwktCFE9cPQ

# Open a file with whatever opener exists on this platform.
open_file(){
    local target="$1"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$target"
    elif command -v start >/dev/null 2>&1; then
        start "$target"
    else
        echo -e "${YELLOW}[*] No opener found for this platform. Open manually: ${NC}$target"
    fi
}

# Escape a string for safe use inside a sed 's|...|...|' replacement.
sed_escape(){
    printf '%s' "$1" | sed -e 's/[\&|]/\\&/g'
}

# Fetch headers for a URL and print "VULNERABLE" or "NOT VULNERABLE".
# Returns 0 if vulnerable, 1 if not, 2 if the request itself failed.
check_clickjacking(){
    local target="$1"
    local headers
    headers=$(curl -s -L -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0" --connect-timeout 5 --head "$target")

    if [ -z "$headers" ]; then
        return 2
    fi

    # X-Frame-Options present at all => treated as protected (DENY/SAMEORIGIN
    # are the only meaningful values in practice; ALLOW-FROM is legacy/ignored
    # by modern browsers, and ALLOWALL isn't a real directive, so its mere
    # presence still indicates the site owner is trying to opt in).
    if echo "$headers" | grep -qi '^X-Frame-Options:'; then
        return 1
    fi

    # Content-Security-Policy only protects against framing if it actually
    # sets frame-ancestors; a CSP with no frame-ancestors directive leaves
    # clickjacking wide open, so check the directive, not just header presence.
    if echo "$headers" | grep -i '^Content-Security-Policy:' | grep -qi 'frame-ancestors'; then
        return 1
    fi

    return 0
}

function banner(){
echo -e ${CP}"     ______ _     ___ ____ _  __         _ _  ____ _  _______ ______       #"
echo -e ${CP}"    / / ___| |   |_ _/ ___| |/ /        | / |/ ___| |/ /___ /|  _ \ \      #"
echo -e ${CP}"   | | |   | |    | | |   | ' /_____ _  | | | |   | ' /  |_ \| |_) | |     #"
echo -e ${CP}"  < <| |___| |___ | | |___| . \_____| |_| | | |___| . \ ___) |  _ < > >    #"
echo -e ${CP}"   | |\____|_____|___\____|_|\_\     \___/|_|\____|_|\_\____/|_| \_\ |     #"
echo -e ${CP}"    \_\                                                           /_/      #"
echo -e ${CNC}"        A Simple Tool To Find ClickJacking Vulnerability With POC          #"
echo -e ${YELLOW}"                         Coded By: Machine404                              #"
echo -e ${CP}"          Follow Me On:  ${CPO}Instagram: invisibleclay100                       #"
echo -e ${CP}"                         ${PINK}Twitter:   whoami4041                             #"
echo -e ${RED}"#############################################################################\n "

}
function single_url(){
clear
banner
echo -e -n ${BLUE}"\n[+] Enter domain name (e.g http|https://target.com/) : "
read url

check_clickjacking "$url"
result=$?

if [ "$result" -eq 2 ]; then
echo -e -n "\n[ ! ] ${NC}$url ${YELLOW}COULD NOT BE REACHED \n"
elif [ "$result" -eq 0 ]; then
echo -e -n "\n[ ✔ ] ${NC}$url ${RED}VULNERABLE \n"
sleep 1
echo -e -n ${BLUE}"\nDo U Want To Open POC In Browser: [y/n]: "
read back_press
if [ "$back_press" = "y" ]; then
if [ -f vuln.html ]; then
rm vuln.html
fi
if [ -f poc.html ]; then
sed "s|vuln|$(sed_escape "$url")|" poc.html > vuln.html
open_file vuln.html
else
 echo -e -n ${RED}"[ X ] POC File Not Found! Exiting"
 exit 1
fi
elif [ "$back_press" = "n" ]; then
if [ -f poc.html ]; then
sed "s|vuln|$(sed_escape "$url")|" poc.html > vuln.html
echo -e -n ${CP}"[+] POC Saved As Vuln.html"
else
echo -e -n ${RED}"[ X ] POC File Not Found! Exiting"
exit 1
fi
sleep 1
exit 0
fi

else

echo -e -n ${CP}"\n[ X ] $url ${CG}NOT VULNERABLE "
fi
}

function mul_url(){
clear
banner
echo -e -n ${CP}"\n[+] Enter path of lists (e.g http|https://target.com/) : "
read urls

if [ ! -f "$urls" ]; then
echo -e -n ${RED}"\n[ X ] List File Not Found! Exiting"
exit 1
fi

# Clear any previous results for this run.
: > vulnerable_urls.txt

while IFS= read -r sanga || [ -n "$sanga" ]; do
[ -z "$sanga" ] && continue

check_clickjacking "$sanga"
result=$?

if [ "$result" -eq 2 ]; then
echo -e -n "\n[ ! ] ${NC}$sanga ${YELLOW}COULD NOT BE REACHED "
elif [ "$result" -eq 0 ]; then
echo -e -n ${BLUE2}"\n[ ✔ ] ${CG}$sanga ${RED}VULNERABLE \n"
echo "$sanga" >> vulnerable_urls.txt
else
echo -e -n ${CP}"\n[ X ] ${NC}$sanga ${YELLOW}NOT VULNERABLE "
fi
done < "$urls"
echo ""
}
trap ctrl_c INT
ctrl_c() {
clear
echo -e ${RED}"[*] (Ctrl + C ) Detected, Trying To Exit... "
echo -e ${RED}"[*] Stopping Services... "
sleep 1
echo ""
echo -e ${YELLOW}"[*] Thanks For Using CLICK-J1CK3R  :)"
exit 0
}

menu()
{
clear
banner
echo -e ${YELLOW}"\n[*] Choose Scanning Type: \n "
echo -e "  ${NC}[${CG}"1"${NC}]${CNC} Single Domain Scan"
echo -e "  ${NC}[${CG}"2"${NC}]${CNC} Multiple Domains Scan"
echo -e "  ${NC}[${CG}"3"${NC}]${CNC} Exit"

echo -n -e ${YELLOW}"\n[+] Select: "
        read redi_play
        case "$redi_play" in
            1) single_url ;;
            2) mul_url ;;
            3) exit 0 ;;
            *) echo -e "\n${RED}[ X ] Invalid selection"; sleep 1; menu ;;
        esac
}
menu
#Coded By Machine404! Don't copy this code without giving me credit~
#https://instagram.com/invisibleclay100
#https://twitter.com/whoami4041
#https://www.youtube.com/channel/UCC_aPnmV_zGfdwktCFE9cPQ
