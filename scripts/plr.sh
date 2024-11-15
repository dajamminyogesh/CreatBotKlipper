#!/bin/bash
# $1 z_height $2 filename $3 z_offset

mkdir -p ~/printer_data/gcodes/.plr
filepath=$(sed -n "s/.*filepath *= *'\([^']*\)'.*/\1/p" /home/klipper/printer_data/config/config_variables.cfg)
filepath=$(printf "$filepath")
echo "$filepath"

last_file=$(sed -n "s/.*last_file *= *'\([^']*\)'.*/\1/p" /home/klipper/printer_data/config/config_variables.cfg)
last_file=$(printf "$last_file")
echo "$last_file"
plr=$last_file
echo "plr=$plr"
PLR_PATH=~/printer_data/gcodes/.plr

file_content=$(cat "${filepath}" | awk '/; thumbnail begin/{flag=1;next}/; thumbnail end/{flag=0} !flag' | grep -v "^;simage:\|^;gimage:")

echo "$file_content" | sed  's/\r$//' | awk -F"Z" 'BEGIN{OFS="Z"} {if ($2 ~ /^[0-9]+$/) $2=$2".0"} 1' > /home/klipper/plrtmpA.$$
sed -i 's/Z\./Z0\./g' /home/klipper/plrtmpA.$$
z_pos=$(echo "${1} + ${3}" | bc)
cat /home/klipper/plrtmpA.$$ | sed -e '1,/Z'${1}'/ d' | sed -ne '/ Z/,$ p' | grep -m 1 ' Z' | sed -ne "s/.* Z\([^ ]*\).*/SET_KINEMATIC_POSITION Z=${z_pos}/p" > ${PLR_PATH}/"${plr}"

cat /home/klipper/plrtmpA.$$ | sed '/ Z'${1}'/q' | sed -ne '/\(M104\|M140\|M109\|M190\)/p' >> ${PLR_PATH}/"${plr}"

line=$(cat /home/klipper/plrtmpA.$$ | sed '/ Z'${1}'/q' | sed -n '/START_PRINT/p')

if [ -n "$line" ]; then
    EXTRUDER=$(echo "$line" | sed -n 's/.*EXTRUDER=\([0-9]*\).*/\1/p')
    EXTRUDER1=$(echo "$line" | sed -n 's/.*EXTRUDER1=\([0-9]*\).*/\1/p')
    BED=$(echo "$line" | sed -n 's/.*BED=\([0-9]*\).*/\1/p')
    CHAMBER=$(echo "$line" | sed -n 's/.*CHAMBER=\([0-9]*\).*/\1/p')
    EXTRUDER=${EXTRUDER:-0}
    EXTRUDER1=${EXTRUDER1:-0}
    BED=${BED:-0}
    CHAMBER=${CHAMBER:-0}

    temp_cmds=("M140 S" "M104 T0 S" "M104 T1 S" "M141 S" "M190 S" "M109 T0 S" "M109 T1 S" "M191 S")
    temps=("$BED" "$EXTRUDER" "$EXTRUDER1" "$CHAMBER" "$BED" "$EXTRUDER" "$EXTRUDER1" "$CHAMBER")

    for i in "${!temps[@]}"; do
        if [ "${temps[$i]}" != "0" ]; then
            echo "${temp_cmds[$i]} ${temps[$i]}" >> "${PLR_PATH}/${plr}"
        fi
    done
fi


cat /home/klipper/plrtmpA.$$ | sed -ne '/;End of Gcode/,$ p' | tr '\n' ' ' | sed -ne 's/ ;[^ ]* //gp' | sed -ne 's/\\\\n/;/gp' | tr ';' '\n' | grep material_bed_temperature | sed -ne 's/.* = /M140 S/p' | head -1 >> ${PLR_PATH}/"${plr}"
cat /home/klipper/plrtmpA.$$ | sed -ne '/;End of Gcode/,$ p' | tr '\n' ' ' | sed -ne 's/ ;[^ ]* //gp' | sed -ne 's/\\\\n/;/gp' | tr ';' '\n' | grep material_print_temperature | sed -ne 's/.* = /M104 S/p' | head -1 >> ${PLR_PATH}/"${plr}"
cat /home/klipper/plrtmpA.$$ | sed -ne '/;End of Gcode/,$ p' | tr '\n' ' ' | sed -ne 's/ ;[^ ]* //gp' | sed -ne 's/\\\\n/;/gp' | tr ';' '\n' | grep material_bed_temperature | sed -ne 's/.* = /M190 S/p' | head -1 >> ${PLR_PATH}/"${plr}"
cat /home/klipper/plrtmpA.$$ | sed -ne '/;End of Gcode/,$ p' | tr '\n' ' ' | sed -ne 's/ ;[^ ]* //gp' | sed -ne 's/\\\\n/;/gp' | tr ';' '\n' | grep material_print_temperature | sed -ne 's/.* = /M109 S/p' | head -1 >> ${PLR_PATH}/"${plr}"


BG_EX=`tac /home/klipper/plrtmpA.$$ | sed -e '/ Z'${1}'[^0-9]*$/q' | tac | tail -n+2 | sed -e '/ Z[0-9]/ q' | tac | sed -e '/ E[0-9]/ q' | sed -ne 's/.* E\([^ ]*\)/G92 E\1/p'`
# If we failed to match an extrusion command (allowing us to correctly set the E axis) prior to the matched layer height, then simply set the E axis to the first E value present in the resemued gcode.  This avoids extruding a huge blod on resume, and/or max extrusion errors.
if [ "${BG_EX}" = "" ]; then
 BG_EX=`tac /home/klipper/plrtmpA.$$ | sed -e '/ Z'${1}'[^0-9]*$/q' | tac | tail -n+2 | sed -ne '/ Z/,$ p' | sed -e '/ E[0-9]/ q' | sed -ne 's/.* E\([^ ]*\)/G92 E\1/p'`
fi
M83=$(cat /home/klipper/plrtmpA.$$ | sed '/ Z'${1}'/q' | sed -ne '/\(M83\)/p')
if [ -n "${M83}" ];then
 echo 'G92 E0' >> ${PLR_PATH}/"${plr}"
 echo ${M83} >> ${PLR_PATH}/"${plr}"
else
 echo ${BG_EX} >> ${PLR_PATH}/"${plr}"
fi
echo 'G91' >> ${PLR_PATH}/"${plr}"
echo 'G1 Z10' >> ${PLR_PATH}/"${plr}"
echo 'G90' >> ${PLR_PATH}/"${plr}"
echo 'G28 X Y' >> ${PLR_PATH}/"${plr}"
cat /home/klipper/plrtmpA.$$ | sed '/ Z'${1}'/q' | sed -ne '/\(ACTIVATE_COPY_MODE\|ACTIVATE_MIRROR_MODE\)/p' >> ${PLR_PATH}/"${plr}"
echo 'G1 X5' >> ${PLR_PATH}/"${plr}"
echo 'G1 Y5' >> ${PLR_PATH}/"${plr}"
cat /home/klipper/plrtmpA.$$ | sed -n '1,/Z'"${1}"'/p'| tac | grep -m 1 -o '^[T][01]' >> ${PLR_PATH}/"${plr}"
echo 'G91' >> ${PLR_PATH}/"${plr}"
echo 'G1 Z-5' >> ${PLR_PATH}/"${plr}"
echo 'G90' >> ${PLR_PATH}/"${plr}"
echo 'M106 S204' >> ${PLR_PATH}/"${plr}"

first_line=$(cat /home/klipper/plrtmpA.$$ |sed -e '1,/Z'${1}'/ d' | sed -ne '/ Z/,$ p' | grep -m 1 ' Z' | grep -E 'F[0-9]+' | sed -E 's/F[0-9]+/F3000/g')
if [ "${first_line}" = "" ];then
    cat /home/klipper/plrtmpA.$$ | sed -e '1,/Z'${1}'/ d' | sed -ne '/ Z/,$ p' >> ${PLR_PATH}/"${plr}"
else
    line=$(cat /home/klipper/plrtmpA.$$ | sed -e '1,/Z'${1}'/ d' | sed -ne '/ Z/,$ p' | grep -m 1 ' Z')
    z_pos=$(echo "$line" | sed -n 's/.*Z\([0-9.]*\).*/\1/p')
    if [[ ${1} != $z_pos ]]; then
        first_line=$(cat /home/klipper/plrtmpA.$$ |sed -e '1,/Z'${1}'/ { /Z'${1}'/!d }' | sed -ne '/ Z/,$ p' | grep -m 1 ' Z' | grep -E 'F[0-9]+' | sed -E 's/F[0-9]+/F3000/g')
    echo ${first_line} >> ${PLR_PATH}/"${plr}"
        cat /home/klipper/plrtmpA.$$ | sed -e '1,/Z'${1}'/ { /Z'${1}'/!d }' | sed -ne '/ Z/,$ p' | tail -n +2 >> ${PLR_PATH}/"${plr}"
    else
        echo ${first_line} >> ${PLR_PATH}/"${plr}"
    cat /home/klipper/plrtmpA.$$ | sed -e '1,/Z'${1}'/ d' | sed -ne '/ Z/,$ p' | tail -n +2 >> ${PLR_PATH}/"${plr}"
    fi
fi
rm /home/klipper/plrtmpA.$$
