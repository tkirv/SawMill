#!/bin/bash
# META =========================================================================
# Title: ParseLog.sh
# Usage: ParseLog.sh -i [log file]
# Description: Parse an event log file.
# Author: Colin Shea
# Created: 2015-06-30
# TODO:
#   - rewrite to use arrays instead of temp files
#     - instead of csplit, use grep to get line numbers, save to array


#   - assemble unique values into reports
#     [message_type]-[message_num]-[line_diff_code]-[word_diff_code]-[a|b]


scriptname=$(basename $0)
function usage {
  echo "Usage: $scriptname -i [log file]"
  echo "Parse a log file."
  echo ""
  echo "  -i, --log-file    log file to parse"
  echo "  -o, --report      output report file"
  echo "  -h, --help        display help"
}

# set input values from command line arguments 
while [[ $# > 0 ]]; do
  arg="$1"
  case $arg in
    # print help
    -h|--help)
    usage
    exit
    ;;
    # log file to parse
    -i|--log-file)
    LOG_FILE="$2"
    shift
    ;;
    # output report file
    -o|--report)
    REPORT_FILE="$2"
    shift
    ;;
    *)
    # unknown option
    echo "Unknown option: $1"
    ;;
  esac
  shift
done


# prepare temp dir, temp files
source /cygdrive/c/users/sheacd/locals/SawMill_local_env.sh 
mkdir -p "${TEMP_DIR}" 
cp "${LOG_FILE}" "${TEMP_DIR}"/
cd "${TEMP_DIR}"
IN_FILE="$(basename $LOG_FILE)"

# sed '/^$/d' - remove blank lines
# csplit options
# -s: silent/quiet mode - don't print file sizes
# -z: elide empty output files (useful when pattern matches first line) 
# -n: use n digits in filename (may need to increase to 7)
# - : use stdin as input (from pipe command)
# use "depth" line as separator (part of ImportHandles log structure)
# {*}: no limit on number of pattern matches (repeat count until input exhausted)

# general form
# parse log by [$1] with csplit to multiple text files (events)
sed '/^$/d' ${IN_FILE} | csplit -s -z -n 5 -f event- - '/^depth/' '{*}'
# for each event
for event in $( find -name "event-*" | sort ); do
  # split on [$2] into header, message
  csplit -s -n 2 -f ${event}- ${event} '/^Ingesting\ package/1' '{*}'
done

# - header - same for all events
#for header in $( find -name "event-*-00" | sort ); do
#  echo "${header}"
#done

# - message - not same for all events
for message in $( find -name "event-*-01" | sort ); do 
  # organize by message type
  message_type=$(head -1 "${message}")
  message_type="${message_type%%\ *}"
  message_type="${message_type//:/}"
  # deal with duplicated message_types
  numlines=$(wc -l "${message}" | awk '{print $1}')
  if [[ "$numlines" -gt "1" && "$(head -1 $message)" == "$(tail -1 $message)" ]]; then
    (( numlines-- ))
  fi
  # save all messages of type message_type to the same file
  head -"$numlines" "${message}" >> msg-"${message_type}"
done

# split each message_type
for message_type_file in $(find -name "msg-*"); do
  message_type=${message_type_file/#\.\/msg-/}
  # note: double-quotes needed to expand variable in csplit
  csplit -s -z -n 5 -f ${message_type}- ${message_type_file} "/${message_type}/" '{*}'
  
  # for each message_type, diff to find which lines vary using #c#
  for message_detail_file in $(find -name "${message_type}-*" | sed 's/\.\///'); do
    diff "${message_type}"-00000 "${message_detail_file}" |
    csplit -s -z -n 2 -f ${message_detail_file}- - '/^[0-9][0-9]*c[0-9][0-9]*$/' '{*}'

    # for each diff line, get diff words
    for diff_line_file in $(find -name "${message_detail_file}-*" | sed 's/\.\///'); do
      diff_line_code="$(head -1 ${diff_line_file} )"
      diff_line_a=$(grep "^<" $diff_line_file)
      diff_line_a="${diff_line_a/#< /}"
      IFS=' ' read -ra diff_line_a_arr <<< "${diff_line_a}"

      diff_line_b=$(grep "^>" $diff_line_file)
      diff_line_b="${diff_line_b/#> /}"
      IFS=' ' read -ra diff_line_b_arr <<< "${diff_line_b}"

      diff <(printf '%s\n' "${diff_line_a_arr[@]}") <(printf '%s\n' "${diff_line_b_arr[@]}") | 
      csplit -s -z -n 2 -f ${message_detail_file}-${diff_line_code}- - '/^[0-9][0-9]*c[0-9][0-9]*$/' '{*}'

      # for each diff word
      for diff_word_file in $(find -name "${message_detail_file}-${diff_line_code}-0*" | sed 's/\.\///'); do
        diff_word_code="$(head -1 ${diff_word_file} )"
        grep "^<" $diff_word_file | sed 's/^[<|>]\ //' | sed 's/\ /\n/g' \
          > ${diff_word_file}-${diff_word_code}-a
        grep "^>" $diff_word_file | sed 's/^[<|>]\ //' | sed 's/\ /\n/g' \
          > ${diff_word_file}-${diff_word_code}-b
      done
    done
  done

done





# message_type_file:    msg-[message].txt
# message_detail_file:  [message]-0000n
# diff_line_file:       [message]-0000n-0n


# diff format
# diff code
# < value
# ---
# > value


# [message_type]-[message_num]-[line_diff_code]-[word_diff_code]-[a|b]

# build array of unique diff-code patterns
# 0 - "1c1;16c16"
#   for each unique diff-code pattern
#     compile all diff-lines for each diff code
#     get list of word #s (field #s) that differ
#     use awk to print a list of the variable words
#     compose template from static words with placeholders


#       - lines that vary (#c#)
#         - for each line #
#           - wdiff (word diff): split each word to separate line
#           - list of variables for distinct words


# Report format
# message_type, count
#   message_details with numbered placeholders for variable words
#   list of variable words, 1 row for each event

# clean up temp dir
#(  && rm -r ${TEMP_DIR} )


# compare each event to first event
# build array of unique diff-code patterns
# within each unique diff-code pattern,
#   if all diff codes are the same AND of form XcX, then it's a unique msg
#   else
#     compare each grouped event to first
#     build array of unique diff-code patterns
#     if all diff codes are the same AND of form XcX, then we've found a unique msg


