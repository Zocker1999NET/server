help() {
  echo "Usage:  $0 <pdf-file> ..."
}

if [[ $# -lt 1 ]]; then
  help >&2
  exit 2
fi

while [[ $# -ge 1 ]]; do
  page_num=$(pdftk "$1" dump_data | awk '/^NumberOfPages:/ {print $2}')
  echo "$page_num" "$1"
  shift 1
done
