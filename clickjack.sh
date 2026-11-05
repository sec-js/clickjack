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

# One URL's scan, run in the background by mul_url's job pool. Writes a
# single-line JSON result to "$1/$2.json" instead of printing straight to
# the aggregate report files, so concurrent workers never interleave writes
# to the same file.
scan_worker(){
local resdir="$1" idx="$2" url="$3"

check_clickjacking "$url"
local rc=$? status

case "$rc" in
0) status="vulnerable" ;;
1) status="not_vulnerable" ;;
*) status="unreachable" ;;
esac

case "$rc" in
0) echo -e ${BLUE2}"\n[ ✔ ] ${CG}$url ${RED}VULNERABLE" ;;
1) echo -e -n ${CP}"\n[ X ] ${NC}$url ${YELLOW}NOT VULNERABLE" ;;
*) echo -e -n "\n[ ! ] ${NC}$url ${YELLOW}COULD NOT BE REACHED" ;;
esac

# JSON-escape backslashes and quotes; URLs shouldn't contain raw newlines,
# control characters, or further JSON-special bytes in practice.
local esc_url=${url//\\/\\\\}
esc_url=${esc_url//\"/\\\"}
printf '{"url":"%s","status":"%s"}\n' "$esc_url" "$status" > "$resdir/$idx.json"
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

echo -e -n ${BLUE}"\n[+] Concurrent requests [default 10]: "
read concurrency
if ! [[ "$concurrency" =~ ^[0-9]+$ ]] || [ "$concurrency" -lt 1 ]; then
concurrency=10
fi

local total
total=$(grep -c . "$urls" 2>/dev/null || echo 0)
echo -e ${CP}"[+] Scanning $total URL(s) with $concurrency concurrent request(s)..."

local resdir
resdir=$(mktemp -d) || { echo -e ${RED}"\n[ X ] Could not create a temp directory! Exiting"; exit 1; }

local start_ts idx=0
start_ts=$(date +%s)

# Portable job pool (no `wait -n`, which pre-4.3 bash/macOS's stock bash
# lacks): track backgrounded PIDs in an array and block on the oldest one
# once the pool is full, so at most $concurrency scans run at a time.
local pids=()
while IFS= read -r sanga || [ -n "$sanga" ]; do
[ -z "$sanga" ] && continue
idx=$((idx + 1))
# Zero-padded so the later glob over result files sorts in the same order
# the URLs were read in (plain "1.json".."10.json" sorts lexicographically,
# putting "10.json" before "2.json" for any list over 9 URLs).
local padded_idx
printf -v padded_idx '%08d' "$idx"
scan_worker "$resdir" "$padded_idx" "$sanga" &
pids+=("$!")
if [ "${#pids[@]}" -ge "$concurrency" ]; then
wait "${pids[0]}" 2>/dev/null
pids=("${pids[@]:1}")
fi
done < "$urls"
for pid in "${pids[@]}"; do
wait "$pid" 2>/dev/null
done

# Aggregate the per-URL result files, oldest-first, into one NDJSON file.
: > "$resdir/all.ndjson"
local f
for f in "$resdir"/*.json; do
[ -e "$f" ] || continue
cat "$f" >> "$resdir/all.ndjson"
done

# Back-compat plain list, as before: one vulnerable URL per line.
: > vulnerable_urls.txt
sed -n 's/^{"url":"\(.*\)","status":"vulnerable"}$/\1/p' "$resdir/all.ndjson" \
| sed -e 's/\\"/"/g' -e 's/\\\\/\\/g' >> vulnerable_urls.txt

# CSV report: url,status (URL field quoted and CSV-escaped).
{
echo "url,status"
while IFS= read -r line; do
[ -z "$line" ] && continue
local u s u_csv
u=$(printf '%s' "$line" | sed -n 's/^{"url":"\(.*\)","status":"\(.*\)"}$/\1/p')
s=$(printf '%s' "$line" | sed -n 's/^{"url":"\(.*\)","status":"\(.*\)"}$/\2/p')
u=$(printf '%s' "$u" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')
u_csv=${u//\"/\"\"}
printf '"%s",%s\n' "$u_csv" "$s"
done < "$resdir/all.ndjson"
} > results.csv

# JSON report: a proper array, built from the NDJSON lines (each already
# valid JSON, generated by this script alone — no external data is ever
# parsed as JSON here, only re-emitted).
{
printf '[\n'
local first=1
while IFS= read -r line; do
[ -z "$line" ] && continue
if [ "$first" -eq 1 ]; then first=0; else printf ',\n'; fi
printf '  %s' "$line"
done < "$resdir/all.ndjson"
printf '\n]\n'
} > results.json

local vulnerable not_vulnerable unreachable elapsed
vulnerable=$(grep -c '"status":"vulnerable"' "$resdir/all.ndjson" 2>/dev/null || echo 0)
not_vulnerable=$(grep -c '"status":"not_vulnerable"' "$resdir/all.ndjson" 2>/dev/null || echo 0)
unreachable=$(grep -c '"status":"unreachable"' "$resdir/all.ndjson" 2>/dev/null || echo 0)
elapsed=$(( $(date +%s) - start_ts ))

rm -rf "$resdir"

echo ""
echo -e ${YELLOW}"\n[*] Scan complete in ${elapsed}s"
echo -e "    ${RED}Vulnerable:${NC} $vulnerable   ${CG}Not vulnerable:${NC} $not_vulnerable   ${YELLOW}Unreachable:${NC} $unreachable"
echo -e ${CP}"[+] Reports written: ${NC}vulnerable_urls.txt, results.csv, results.json"
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
