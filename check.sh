#!/bin/bash
#
# while :; do ./check.sh ; sleep 900; done

DEFAULT_URL='https://jenaplan-weimar.de/vertretungsplan/'
DEFAULT_PATTERN='8c\|Büf'

URL="${1:-$DEFAULT_URL}"
PATTERN="${2:-$DEFAULT_PATTERN}"	# e.g. regex: '8c\|Büf' or '10c\|10+'
NOTIFY="$3"				# e.g. JID => 49176xxxXXXxx@s.whatsapp.net

command -v 'phantomjs' >/dev/null || { echo "missing 'phantomjs' in PATH from https://phantomjs.org/download.html"; exit 1; }
command -v 'mdtest'    >/dev/null || { echo "missing 'mdtest' in PATH from https://github.com/tulir/whatsmeow/tree/main/mdtest"; exit 1; }

test -f mdtest.db || { echo "missing 'mdtest.db' in '$PWD' - please run 'mdtest' and scan qrcode"; exit 1; }

SCRIPTDIR="$( CDPATH='' cd -- "$( dirname -- "$0" )" && pwd )"
cd "$SCRIPTDIR"        || exit 1
TEMPFILE="$( mktemp )" || exit 1

LOG="$SCRIPTDIR/log.txt"
HTML="$SCRIPTDIR/data/plan.html"
mkdir -p "$SCRIPTDIR/data"
test -d "$SCRIPTDIR/data/.git" || ( cd "$SCRIPTDIR/data" && git init )

html_screenshot()
{
	local file="$TEMPFILE"
	local image='plan.png'
	local url=

	cp "$file" foo.html && url="file://$PWD/foo.html"

	cat >phantomjs.script <<EOF
var page = require('webpage').create();
page.open('$url', function() {
    setTimeout(function() {
        page.render('$image');
        phantom.exit();
    }, 200);
});
EOF
	phantomjs phantomjs.script
	rm phantomjs.script foo.html && echo "plan.png"
}

# e.g.: https://vplan.jenaplan-weimar.de/Vertretungsplaene/SchuelerInnen/subst_001.htm
for URL_IFRAME in $( wget -qO - "$URL" | grep '<iframe src=' | tr '"' ' ' ); do {
	case "$URL_IFRAME" in
		http*) break ;;
	esac
} done

wget -qO "$HTML" "${URL_IFRAME:-$URL}" && \
	cd "$SCRIPTDIR/data" && {
		git add 'plan.html'
		git commit --author="bot <bot@script.me>" -m "new plan" >/dev/null
		cd - >/dev/null || exit 1
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

whatsapp_send_image()
{
	pidof mdtest || return 1
	coproc whatsapp_send { mdtest; }
	echo "sendimg $NOTIFY $IMAGE" >&"${whatsapp_send[1]}"

	while read -r LINE; do {
		case "$LINE" in *"was delivered to $NOTIFY at"*) echo "[OK] send to $NOTIFY" && return ;; esac
	} done <&"${whatsapp_send[0]}"
}

if MATCH="$( grep "$PATTERN" "$TEMPFILE" )"; then
	HASH="$( echo "$MATCH" | md5sum | cut -d' ' -f1 )"

	if grep -sq "$HASH to $NOTIFY" "$LOG"; then
		echo "Treffer gefunden, schon benachrichtigt"
	else
		IMAGE="$( html_screenshot )"
		echo "Treffer gefunden, sende Nachricht" && whatsapp_send_image
		echo "$( date ) send $HASH to $NOTIFY" >>"$LOG"
	fi
else
	echo "kein Treffer für '$PATTERN'"
fi

rm -f "$TEMPFILE"
