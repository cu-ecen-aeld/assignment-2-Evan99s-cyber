if [ $# -ne 2 ]; then
	echo "Error: L1"
	exit 1
fi

writefile="$1"
writestr="$2"

dirpath=$(dirname "$writefile")
mkdir -p "$dirpath"

echo "$writestr" > "$writefile"
if [ $? -ne 0 ]; then
        echo "Error: L2"
        exit 1
fi
