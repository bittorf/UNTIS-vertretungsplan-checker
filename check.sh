#!/bin/sh
#
# while :; do ./check.sh ; sleep 900; done

DEFAULT_URL='https://jenaplan-weimar.de/vertretungsplan/'
DEFAULT_PATTERN='8c\|Büf'

URL="${1:-$DEFAULT_URL}"
PATTERN="${2:-$DEFAULT_PATTERN}"	# e.g. regex: '8c\|Büf' or '10c\|10+'

DEST_URL="http://10.63.22.98/2.html"
DEST_SCP="bastian@10.63.22.98:/var/www/html/2.html"

SCRIPTDIR="$( CDPATH='' cd -- "$( dirname -- "$0" )" && pwd )"
TEMPFILE="$( mktemp )" || exit 1
HTML="$SCRIPTDIR/data/plan.html"
mkdir -p "$SCRIPTDIR/data"
test -d "$SCRIPTDIR/data/.git" || ( cd "$SCRIPTDIR/data" && git init )

log()
{
	echo "$*" >>"$SCRIPTDIR/log.txt"
}

# e.g.: https://vplan.jenaplan-weimar.de/Vertretungsplaene/SchuelerInnen/subst_001.htm
for URL_IFRAME in $( wget -qO - "$URL" | grep '<iframe src=' | tr '"' ' ' ); do {
	case "$URL_IFRAME" in
		http*) break ;;
	esac
} done

wget -qO "$HTML" "$URL_IFRAME" && \
	cd "$SCRIPTDIR/data" && {
		git add 'plan.html'
		git commit --author="bot <bot@script.me>" -m "new plan" >/dev/null
	}

while read -r LINE; do {
	case "$LINE" in
		"<tr class='list odd'>"*|\
		"<tr class='list even'>"*)
			COLUMN=0
			for WORD in $LINE; do {
				case "$WORD" in
					*'</td>'*)
						COLUMN=$(( COLUMN+1 ))
						[ "$COLUMN" = 3 ] && {
							echo "$WORD" | grep -q "$PATTERN" && echo "$LINE"
							break
						}
					;;
				esac
			} done
		;;
		*)
			echo "$LINE"
		;;
	esac
} done <"$HTML" >"$TEMPFILE"

if grep -q "$PATTERN" "$TEMPFILE"; then
	echo "Treffer gefunden" && scp "$TEMPFILE" "$DEST_SCP" && echo "see: $DEST_URL" # && grep --color "$PATTERN" "$TEMPFILE"
else
	echo "kein Treffer für '$PATTERN'"
fi

rm -f "$TEMPFILE"
