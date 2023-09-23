#!/bin/sh

PATTERN="${1:-.}"	# e.g. regex | 8c Büffel oder z.b. 10c Digdigs oder 10+...

URL="https://jenaplan-weimar.de/vertretungsplan/"
DEST_URL="http://10.63.22.98/2.html"
DEST_SCP="bastian@10.63.22.98:/var/www/html/2.html"

SCRIPTDIR="$( CDPATH= cd -- "$( dirname -- "$0" )" && pwd )"
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
		git commit --author="bot <bot@script.me>" -m "new plan" >/dev/null || exit
	}

while read -r LINE; do {
	case "$LINE" in
		"<tr class='list odd'>"*|\
		"<tr class='list even'>"*)
			echo "$LINE" | grep "$PATTERN"
		;;
		*)
			echo "$LINE"
		;;
	esac
} done <"$HTML" >"$TEMPFILE"

grep -q "$PATTERN" "$TEMPFILE" && echo "Treffer gefunden" && scp "$TEMPFILE" "$DEST_SCP" && echo "see: $DEST_URL"
rm -f "$TEMPFILE"