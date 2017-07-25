help (){
  echo "Usage: JIRA_USER=jira-user JIRA_PASSWORD=password123 test-patch.sh SOLR-12345"
}
if [ -z "$JIRA_USER" ]; then
  help;
  exit 1;
fi

PROJECT_DIR=~/repos/solr-yetus-test
#YETUS_BIN=~/Downloads/yetus-0.4.0/bin
YETUS_BIN=~/repos/yetus/
#YETUS_CMD=test-patch
YETUS_CMD=precommit/test-patch.sh

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

#	--plugins="ant,jira,javac,unit,junit,author,test4tests,checkluceneversion,ratsources,checkforbiddenapis,checklicenses" \
#	--plugins="ant,jira,javac,checklicenses" \
$YETUS_BIN/$YETUS_CMD \
  --personality=$SCRIPT_DIR/solr-yetus-personality.sh \
	--basedir=$PROJECT_DIR \
	--branch=master \
	--project=SOLR \
	--jira-user=$JIRA_USER \
	--jira-password=$JIRA_PASSWORD \
	--debug \
	--skip-dirs="dev-tools" \
	--bugcomments=jira \
	--build-tool=ant \
	--resetrepo \
	--run-tests \
 	----robot \
	$1