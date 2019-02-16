#!/bin/bash
# based on: https://gist.github.com/s-leroux/7cb7424d33ba3753e907cc2553bcd1ba
# modified by: cca
set -u -o pipefail
set_dir(){ _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; }; set_dir
safe_source () { source $1; set_dir; }
# end of bash boilerplate

print_usage(){
  cat << USAGE

    usage:

        $(basename $0) /path/to/file Github_user_name

        or

        lsusb | $(basename $0) Github_user_name

USAGE
}

# 0. Your file name
FNAME="${1:-}"
if [[ -f "$FNAME" ]]; then
  CONTENT=$(cat "$FNAME")
  GITHUB_TOKEN="${2:-}"
else
  CONTENT=$(timeout 2 cat -)
  GITHUB_TOKEN="${1-}"
  FNAME="stdin"
  if [[ "$CONTENT" == "" ]]; then
    print_usage
    exit 2
  fi
fi

# Github does not permit anonymous uploads since April 2018
if [[ -z $GITHUB_TOKEN ]]; then
    print_usage
    exit 2
fi


# 1. JSON-Stringify the file content:
#    Replace \ with \\
#    Remove \r (from Windows end-of-lines)
#    Replace tabs with \t
#    Replace " with \"
#    Replace EOL with \n
CONTENT=$(echo "${CONTENT}" | sed -e 's/\\/\\\\/g' -e 's/\r//' -e's/\t/\\t/g' -e 's/"/\\"/g' | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g')

# 2. Get the description
read -p "Give a description: " DESCRIPTION

# 3. Build the JSON request
tmp_file=$(mktemp)
cat > $tmp_file  <<EOF
{
  "description": "$DESCRIPTION",
  "public": true,
  "files": {
    "$(basename $FNAME)": {
      "content": "${CONTENT}"
    }
  }
}
EOF

# 4. Use curl to make a POST request
OUTPUT=$(curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST -d @$tmp_file "https://api.github.com/gists")
uploaded_url=$(echo "$OUTPUT" | grep 'html_url' | grep 'gist')

# 5. cleanup the tmp file
rm $tmp_file

# 6. Show the output
if [[ ! -z ${uploaded_url:-} ]]; then
  echo "URL: "
  echo "-----------------"
  echo $uploaded_url
else
  echo "----- ERROR -----"
  echo "$OUTPUT"
  echo "-----------------"
fi
