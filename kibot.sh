#!/bin/bash

# run this script to generate stuff defined in ./project/.kibot.yaml file
# ./kibot.sh

set -e
uid=$(id -u)
gid=$(id -g)


function run_kibot() {
	time docker run --rm -it \
	--volume "$(pwd):/tmp/workdir" \
	--workdir "/tmp/workdir" \
	setsoft/kicad_auto:ki6.0.10_Debian \
	/bin/bash -c "groupadd -g$gid u; useradd -u$uid -g$gid -d/tmp u; su u -c 'cd project && kibot -c .kibot.yaml $*'"
}

if [ "$1" ]; then
	echo "executing kibot with params: $*"
	run_kibot $*
	exit 0
fi


# generate documentation stuff
run_kibot --out-dir ../gen/ --board pwr.kicad_pcb  print_sch pcb_print img_3d_pwr_front img_3d_pwr_back
run_kibot --out-dir ../gen/ --board  ui.kicad_pcb  print_sch pcb_print img_3d_ui_front  img_3d_ui_back


# generate single board fab stuff
run_kibot --skip-pre all --board pwr.kicad_pcb --out-dir ../gen/pwr_single ibom fab_gerbers fab_drill fab_netlist fab_position full_bom lcsc_bom
run_kibot --skip-pre all --board  ui.kicad_pcb --out-dir ../gen/ui_single  ibom fab_gerbers fab_drill fab_netlist fab_position full_bom lcsc_bom


# concat pcb pdfs
run_kibot --skip-pre all --out-dir ../gen/ merge_pcb_pdf
rm ./gen/pcb_*.pdf

# remove garbage changes from pdfs
sed -i '/[/]CreationDate.*$/d' ./gen/schematics*.pdf
sed -i '/[/]CreationDate.*$/d' ./gen/pcb*.pdf


# make gerber generation reproducible for git
sed -i \
	-e '/^.*TF.CreationDate.*$/d' \
	-e '/^.*G04 Created by KiCad.* date .*$/d' \
	-e '/^.*DRILL file .* date .*$/d' \
	./gen/*/*.{gbr,drl}


# move files around

#cp -f ./gen/bom.csv ./gen/pwr_single/_bom.csv

# archive 

function archive() {
	dir="$(dirname "$1")"
	rm -f $1
	touch -cd 1970-01-01T00:00:00Z $dir/*
	zip -qjorX9 -n zip $1 $dir
}
archive ./gen/pwr_single/_prod_pwr.zip
archive ./gen/ui_single/_prod_ui.zip



