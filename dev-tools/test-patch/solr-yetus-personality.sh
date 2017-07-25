#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

personality_plugins "ant,jira,javac,unit,junit,author,test4tests,checkluceneversion,ratsources,checkforbiddenapis,checklicenses"
#personality_plugins "ant,jira,javac,checkluceneversion,ratsources,checkforbiddenapis,checklicenses"

## @description  Globals specific to this personality
## @audience     private
## @stability    evolving
function personality_globals
{
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=master
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^SOLR-[0-9]+$'
  #shellcheck disable=SC2034
  JIRA_STATUS_RE='Open'
  #shellcheck disable=SC2034
  GITHUB_REPO="apache/lucene-solr"
  #shellcheck disable=SC2034
  BUILDTOOL=ant
  PATCH_NAMING_RULE="https://wiki.apache.org/solr/HowToContribute#Generating_a_patch"

}

## @description  Queue up modules for this personality
## @audience     private
## @stability    evolving
## @param        repostatus
## @param        testtype
function personality_modules
{
  local repostatus=$1
  local testtype=$2

  local module
  local extra

  local moduleType="submodules"


  yetus_debug "Personality (solr): ${repostatus} ${testtype}"

  clear_personality_queue

  case ${testtype} in
    distclean)
      extra="clean"
      ;;
    checkluceneversion)
      moduleType="solr"
      ;;
    ratsources)
      moduleType="both"
      ;;
    checkforbiddenapis)
      moduleType="both"
      ;;
    checklicenses)
      moduleType="mains"
      ;;
    compile)
      moduleType="submodules"
      ;;
    unit)
      extra="-Dtests.jvms=8 test"
      moduleType="submodules"
      ;;
    *)
      moduleType="submodules"
    ;;
  esac

  case ${moduleType} in
    submodules)
      for module in "${CHANGED_MODULES[@]}"; do
        if [[ "$module" =~ ^solr/core ]]; then
          echo ${module} "-> solr/core"
          personality_enqueue_module "solr/core" "$extra"
        fi
        if [[ "$module" =~ ^solr/solrj ]]; then
          echo ${module} "-> solr/solrj"
          personality_enqueue_module "solr/solrj" "$extra"
        fi
        if [[ "$module" =~ ^solr/contrib ]]; then
          echo ${module} "-> solr/contrib"
          personality_enqueue_module "${module}" "$extra"
        fi
        if [[ "$module" =~ ^lucene/ ]]; then
          echo ${module} "-> ${module}"
          personality_enqueue_module "${module}" "$extra"
        fi
      done
      ;;
    lucene)
      personality_enqueue_module "lucene" "$extra"
      ;;
    solr)
      personality_enqueue_module "solr" "$extra"
      ;;
    top)
      personality_enqueue_module "" "$extra"
      ;;
    mains)
      personality_enqueue_module "lucene" "$extra"
      personality_enqueue_module "solr" "$extra"
      ;;
    both) # solr, lucene, or both
      local doSolr
      local doLucene
      for module in "${CHANGED_MODULES[@]}"; do
        if [[ "$module" =~ ^solr/ ]]; then doSolr=1; fi
        if [[ "$module" =~ ^lucene/ ]]; then doLucene=1; fi
      done
      if [[ $doLucene = 1 && $doSolr = 1 ]]; then
        personality_enqueue_module "" "$extra"
      else
        if [[ $doLucene = 1 ]]; then personality_enqueue_module "lucene" "$extra"; fi
        if [[ $doSolr = 1 ]]; then personality_enqueue_module "solr" "$extra"; fi
      fi
      ;;
    *)
    ;;
  esac

#  for module in "${CHANGED_MODULES[@]}"; do
#    if [[ "$module" =~ ^(solr|lucene)$ ]]; then
#      echo ${module}
#      personality_enqueue_module "${module}" "$extra"
#    fi
#  done
}

add_test_type "checkluceneversion"
add_test_type "ratsources"
add_test_type "checkforbiddenapis"
add_test_type "checklicenses"



function checkluceneversion_precompile
{
  declare repostatus=$1
  solr_ant_command ${repostatus} "checkluceneversion" "check-example-lucene-match-version" "Check examples refer correct lucene version"
}

function ratsources_precompile
{
  declare repostatus=$1
  solr_ant_command ${repostatus} "ratsources" "rat-sources" "Release audit (RAT)"
}

function checkforbiddenapis_precompile
{
  declare repostatus=$1
  solr_ant_command ${repostatus} "checkforbiddenapis" "check-forbidden-apis" "Check forbidden APIs"
}

function checklicenses_precompile
{
  declare repostatus=$1
  solr_ant_command ${repostatus} "checklicenses" "check-licenses" "Check licenses"
}


function solr_ant_command
{
  declare repostatus=$1
  declare testname=$2
  declare antcommand=$3
  declare title=$4

  declare result=0
  declare i=0
  declare module
  declare fn
  declare result

  if [[ "${repostatus}" = branch ]]; then
    return 0
  fi

  big_console_header "${title}"
  personality_modules $repostatus $testname
  start_clock
  until [[ ${i} -eq ${#MODULE[@]} ]]; do
    if [[ ${MODULE_STATUS[${i}]} == -1 ]]; then
      ((result=result+1))
      ((i=i+1))
      continue
    fi
    ANT_ARGS=${antcommand}

    module=${MODULE[$i]}
    fn=$(module_file_fragment "${module}")
    logfilename="${repostatus}-${antcommand}-${fn}.txt";
    logfile="${PATCH_DIR}/${logfilename}"
    buildtool_cwd "${i}"
    echo_and_redirect "${logfile}" \
        $(ant_executor)

    if [[ $? == 0 ]] ; then
      module_status ${i} +1 "${logfilename}" "${title}"\
          "${antcommand} passed"
    else
      module_status ${i} -1 "${logfilename}" "${title}"\
          "${antcommand} failed"
      ((result = result + 1))
    fi
    ((i=i+1))
  done
  ANT_ARGS=""
  if [[ ${result} -gt 0 ]]; then
    modules_messages ${repostatus} "${title}" false
    return 1
  fi
  modules_messages ${repostatus} "${title}" true
  return 0
}


function ___personality_file_tests
{
  local filename=$1

  yetus_debug "Using personality_file_tests (solr)"

  if [[ ${filename} =~ \.sh
       || ${filename} =~ \.cmd
       ]]; then
    yetus_debug "tests/shell: ${filename}"
  elif [[ ${filename} =~ \.c$
       || ${filename} =~ \.cc$
       || ${filename} =~ \.h$
       || ${filename} =~ \.hh$
       || ${filename} =~ \.proto$
       || ${filename} =~ src/test
       || ${filename} =~ \.cmake$
       || ${filename} =~ CMakeLists.txt
       ]]; then
    yetus_debug "tests/units: ${filename}"
    add_test javac
    add_test unit
  elif [[ ${filename} =~ build.xml
       || ${filename} =~ ivy.xml
       || ${filename} =~ \.java$
       ]]; then
      yetus_debug "tests/javadoc+units: ${filename}"
      add_test javac
      add_test unit
      add_test author
      add_test test4tests
      add_test "check-example-lucene-match-version"
      add_test "rat-sources"
      add_test "check-forbidden-apis"
      add_test "check-licenses"

  fi
}