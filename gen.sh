#!/bin/bash

# Dependencies
# gcc (7+), imagemagick, unzip, gcc-mingw-w64
# Script tested on Ubuntu 16.04, may need some adpatations for other OS. PR welcomed.


# Variables
UNICODE_VERSION="13.0"
UNIFONT_VERSION="13.0.06"
U8G2_VERSION="master"



# Init
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

RES_DIR="$DIR/resources"
WORK_DIR="$DIR/work"
mkdir -p "$WORK_DIR"
rm -rf "${WORK_DIR}"/*
DIST_DIR="$DIR/docs"
mkdir -p "$DIST_DIR"
rm -rf "${DIST_DIR}"/*
DATE="$(date '+%Y-%m-%d')"



# Build unifont
cd "$WORK_DIR"
wget "https://unifoundry.com/pub/unifont/unifont-${UNIFONT_VERSION}/unifont-${UNIFONT_VERSION}.tar.gz"
tar -xf unifont-${UNIFONT_VERSION}.tar.gz
cd "$WORK_DIR/unifont-${UNIFONT_VERSION}/font"
patch -i "$RES_DIR/fullfont.diff" Makefile   ## merge bmp & smp in same font
cd "$WORK_DIR/unifont-${UNIFONT_VERSION}"
make BUILDFONT=1  ## dont care if error (bdftopcf not found)
cp "$WORK_DIR/unifont-${UNIFONT_VERSION}/font/compiled/unifont-${UNIFONT_VERSION}.bdf" "$DIST_DIR"



# Build bdfconv
cd "$WORK_DIR"
wget "https://github.com/olikraus/u8g2/archive/refs/heads/${U8G2_VERSION}.zip"
unzip "${U8G2_VERSION}.zip"
cd "$WORK_DIR/u8g2-${U8G2_VERSION}/tools/font/bdfconv"
rm *.exe
gcc -g bdf*.c fd.c main.c -o bdfconv
cp "$WORK_DIR/u8g2-${U8G2_VERSION}/tools/font/bdfconv/bdfconv" "$DIST_DIR"
i686-w64-mingw32-gcc -g bdf*.c fd.c main.c -o bdfconv.exe
cp "$WORK_DIR/u8g2-${U8G2_VERSION}/tools/font/bdfconv/bdfconv.exe" "$DIST_DIR"



# Create our JSON
cd "${WORK_DIR}"

echo -n "const planes = {" > temp.json

while read PLANE; do
	PLANE_RANGE="$(echo $PLANE | cut -d'|' -f1)"
	PLANE_NAME="$(echo $PLANE | cut -d'|' -f2)"
	PLANE_ID="$(echo $PLANE_NAME | tr '[:upper:]' '[:lower:]' | sed 's| |-|g' | sed "s|'|-|g")"

	RANGE_MIN="$(echo $PLANE_RANGE | cut -d'-' -f1)"
	RANGE_MAX="$(echo $PLANE_RANGE | cut -d'-' -f2)"

	if (( $(( ${RANGE_MAX}-${RANGE_MIN} )) > 1599 )); then
		PICTURE_RANGE="$(echo "${RANGE_MIN}-$(( ${RANGE_MIN} + 1599 ))")"
	else
		PICTURE_RANGE="${PLANE_RANGE}"
	fi

	${DIST_DIR}/bdfconv -m "$PICTURE_RANGE" ${DIST_DIR}/unifont-${UNIFONT_VERSION}.bdf -o ${WORK_DIR}/dummy.c -n dummy -d ${DIST_DIR}/unifont-${UNIFONT_VERSION}.bdf

	convert ${WORK_DIR}/bdf.tga -gravity North -chop x53 +repage -trim +repage -bordercolor white -border 3 +repage ${WORK_DIR}/bdf.png

	echo -n "${JSON}@$PLANE_ID@:{r:@$PLANE_RANGE@,t:@$PLANE_NAME@,i:@data:image/png;base64,$(cat ${WORK_DIR}/bdf.png | base64 -w 0)@}," >> temp.json

	rm -f ${WORK_DIR}/bdf.tga ${WORK_DIR}/bdf.png ${WORK_DIR}/dummy.c
	echo -n "."

done <"$RES_DIR/planes.txt"

sed -i -e 's|.$|};|' -e 's|@|"|g' temp.json



# Fill the template
sed '/@@PLANES@@/{s///;q;}' "$RES_DIR/index.html" | sed -e "s|@@UNICODE_VERSION@@|$UNICODE_VERSION|" -e "s|@@UNIFONT_VERSION@@|$UNIFONT_VERSION|g" -e "s|@@U8G2_VERSION@@|$U8G2_VERSION|" -e "s|@@DATE@@|$DATE|"> "$DIST_DIR/index.html"
cat "${WORK_DIR}/temp.json" >> "$DIST_DIR/index.html"
tac "$RES_DIR/index.html" | sed '/@@PLANES@@/{s///;q;}' | tac >> "$DIST_DIR/index.html"




# Cleanup & exit
rm -rf "$WORK_DIR"
echo
echo
echo "Job done!"
echo
echo "Files created:"
echo " - unifont-${UNIFONT_VERSION}.bdf     Unifont font file, with both BMP and SMP"
echo " - bdfconv                 Tool to convert chars from .bdf fonts to u8g2 [Linux]"
echo " - bdfconv.exe             Tool to convert chars from .bdf fonts to u8g2 [Windows]"
echo " - index.html              Helper to generate bdfconv command line params"



