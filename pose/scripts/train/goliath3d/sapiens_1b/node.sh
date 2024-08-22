cd ../../../..

###--------------------------------------------------------------
# DEVICES=0,
DEVICES=0,1,2,3,4,5,6,7,

RUN_FILE='./tools/dist_train.sh'
PORT=$(( ((RANDOM<<15)|RANDOM) % 63001 + 2000 ))

##---------copy this to the slurm script-----------------
####-----------------MODEL_CARD----------------------------
DATASET='goliath3d'
MODEL="sapiens_1b_${DATASET}"
JOB_NAME="pose3d_$MODEL"
TRAIN_BATCH_SIZE_PER_GPU=3

RESUME_FROM=''
LOAD_FROM=''
LOAD_FROM='/home/rawalk/Desktop/sapiens/pose/Outputs/train/goliath3d/sapiens_1b_goliath3d/slurm/pose2d_08-08-2024_15:17:28/iter_8000.pth'

#---------------------------------------------------------------
# mode='debug'
mode='multi-gpu'

###--------------------------------------------------------------
CONFIG_FILE=configs/sapiens_pose3d/${DATASET}/${MODEL}.py
OUTPUT_DIR="Outputs/train/${DATASET}/${MODEL}/node"
OUTPUT_DIR="$(echo "${OUTPUT_DIR}/$(date +"%m-%d-%Y_%H:%M:%S")")"

###--------------------------------------------------------------
if [ -n "$LOAD_FROM" ]; then
    OPTIONS="train_dataloader.batch_size=$TRAIN_BATCH_SIZE_PER_GPU load_from=$LOAD_FROM"
else
    OPTIONS="train_dataloader.batch_size=$TRAIN_BATCH_SIZE_PER_GPU"
fi

if [ -n "$RESUME_FROM" ]; then
    CMD_RESUME="--resume ${RESUME_FROM}"
else
    CMD_RESUME=""
fi

export TF_CPP_MIN_LOG_LEVEL=2

##--------------------------------------------------------------
if [ "$mode" = "debug" ]; then
    TRAIN_BATCH_SIZE_PER_GPU=1

    OPTIONS="$(echo "train_dataloader.batch_size=${TRAIN_BATCH_SIZE_PER_GPU} train_dataloader.num_workers=0 train_dataloader.persistent_workers=False")"

    if [ -n "$LOAD_FROM" ]; then
        OPTIONS="${OPTIONS} load_from=${LOAD_FROM}"
    fi

    CUDA_VISIBLE_DEVICES=${DEVICES} python tools/train.py ${CONFIG_FILE} --work-dir ${OUTPUT_DIR} --no-validate --cfg-options ${OPTIONS}

elif [ "$mode" = "multi-gpu" ]; then
    NUM_GPUS_STRING_LEN=${#DEVICES}
    NUM_GPUS=$((NUM_GPUS_STRING_LEN/2))
    SEED='0'

    LOG_FILE="$(echo "${OUTPUT_DIR}/log.txt")"
    mkdir -p ${OUTPUT_DIR}; touch ${LOG_FILE}

    CUDA_VISIBLE_DEVICES=${DEVICES} PORT=${PORT} ${RUN_FILE} ${CONFIG_FILE} \
            ${NUM_GPUS} \
            --work-dir ${OUTPUT_DIR} \
            --seed ${SEED} \
            --cfg-options ${OPTIONS} \
            ${CMD_RESUME} \
            | tee ${LOG_FILE}

fi
