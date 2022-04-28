#!/bin/bash

# trap error
set -eo pipefail
err_report(){
  echo "Fail at $1: $2"
}
trap 'err_report ${LINENO} "${BASH_COMMAND}"' ERR


### arguments
while getopts 'hi:b:r:m:d:o:' flag; do
    case $flag in
        h)
            echo "Predict the polygenic risk score for individuals"
            echo "options:"
            echo "-i, input bfile prefix"
            echo "-b, beta file (beta.csv)"
            echo "-r, reference rank file (rank.csv)"
            echo "-m, type of the trait; 'clf' (binary) or 'reg' (quantitative)"
            echo "-d, output directory"
            echo "-o, output basename"
            ;;
        i) BFILE=$OPTARG;;
        b) MODEL=$OPTARG;;
        r) RANK=$OPTARG;;
        m) METHOD=$OPTARG;;
        d) WORK_DIR=$OPTARG;;
        o) BASENAME=$OPTARG;;
        *) echo "usage: $0 [-i] [-b] [-r] [-m] [-d] [-o]"; exit 1;;
    esac
done

CURRENT_DIR=$(pwd)
SRC_DIR=$(dirname $0)
mkdir -p ${WORK_DIR}


### remove duplicates
plink1.9 \
    --bfile "${BFILE}" \
    --list-duplicate-vars suppress-first \
    --allow-no-sex \
    --allow-extra-chr \
    --out "${WORK_DIR}/${BASENAME}.dup"

plink2 \
    --bfile "${BFILE}" \
    --rm-dup force-first \
    --allow-extra-chr \
    --exclude "${WORK_DIR}/${BASENAME}.dup.dupvar" \
    --make-bed \
    --out "${WORK_DIR}/${BASENAME}.dedup"


### predict by algorithms
# MODEL columns = ['#CHROM','POS','ID','REF','ALT','A1','P','BETA', ALGO_1, ALGO_2, ...]
read -ra COLS < ${MODEL}
for ((i=8; i<${#COLS[@]}; i++));do
    ALGO=${COLS[i]}
    printf "\n\n\n###### Predict with ${ALGO} ######\n\n\n"
    plink1.9 \
        --bfile "${WORK_DIR}/${BASENAME}.dedup" \
        --score "${MODEL}" 3 6 $((i+1)) header sum \
        --allow-extra-chr \
        --allow-no-sex \
        --out "${WORK_DIR}/${BASENAME}.${ALGO}"
done


### remove temp files
rm ${WORK_DIR}/${BASENAME}.dedup.* || true
rm ${WORK_DIR}/${BASENAME}.dup.* || true


### merge predictions and calculate the rank
cd ${SRC_DIR} || exit
python3 - << EOF
from utils import *
os.chdir("${CURRENT_DIR}")
pred = Predictions("${BFILE}", "${WORK_DIR}/${BASENAME}", "${METHOD}", "${RANK}")
pred()
pred.df.to_csv("${WORK_DIR}/${BASENAME}.prediction.csv", index=False)
pred.rank_df.to_csv("${WORK_DIR}/${BASENAME}.rank.csv", index=False)
EOF
cd ${CURRENT_DIR} || exit