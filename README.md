### Setup
* install 'phantomjs' from https://phantomjs.org/download.html
´´´
# needs root permissions!
# extract 'phantomjs' into '/usr/local/bin' and make it executable
URL=https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
curl -L $URL | tar -C /usr/local/bin -xvjf - --absolute-names --no-anchored phantomjs --transform='s:.*/::'
command -v phantomjs
´´´

### ToDo:
* Nachrichten zum Tag auch nach Relevanz filtern?
