#!/bin/bash

# Navigate two levels up from the current directory
cd ../../../.. || exit

# Set the configurations for detection and pose estimation
RUN_FILE='demo/save_normal.py'

DATA_DIR='/mnt/home/rawalk/Desktop/sapiens/seg/data'
OUTPUT_DIR='/mnt/home/rawalk/Desktop/sapiens/seg/Outputs/test'

####--------------------------vit-mammoth, pretrained shutterstock, trained on goliath + all, iter 600, 64 nodes---------------
DATASET='normal_render_people'
MODEL="sapien_0.6b_${DATASET}-1024x768"

CONFIG_FILE="configs/sapiens_normal/${DATASET}/${MODEL}.py"
CHECKPOINT='/mnt/home/rawalk/sapiens_host/normal/checkpoints/sapien_0.6b/sapien_0.6b_normal_render_people_epoch_200.pth'

# ###--------------------------------data:goliath--------------------------------------------------
# DATA_PREFIX="thuman2/evaluation/face/rgb"
# DATA_PREFIX="thuman2/evaluation/full_body/rgb"
# DATA_PREFIX="thuman2/evaluation/upper_half/rgb"

DATA_PREFIX="hi4d/evaluation/rgb"

##------------------------------------------------------------------------------
INPUT="${DATA_DIR}/${DATA_PREFIX}"
CHECKPOINT_NAME=$(basename "${CHECKPOINT}" .pth)
OUTPUT="${OUTPUT_DIR}/${DATASET}/${MODEL}/${DATA_PREFIX}"

# JOBS_PER_GPU=4; TOTAL_GPUS=8; VALID_GPU_IDS=(0 1 2 3 4 5 6 7)
# JOBS_PER_GPU=1; TOTAL_GPUS=1; VALID_GPU_IDS=(5)
JOBS_PER_GPU=2; TOTAL_GPUS=4; VALID_GPU_IDS=(4 5 6 7)

TOTAL_JOBS=$((JOBS_PER_GPU * TOTAL_GPUS))

# Find all images and sort them, then write to a temporary text file
IMAGE_LIST="${INPUT}/image_list.txt"
find "${INPUT}" -type f \( -iname \*.jpg -o -iname \*.png \) | sort > "${IMAGE_LIST}"

# Check if image list was created successfully
if [ ! -s "${IMAGE_LIST}" ]; then
  echo "No images found. Check your input directory and permissions."
  exit 1
fi

# Count images and calculate the number of images per text file
NUM_IMAGES=$(wc -l < "${IMAGE_LIST}")
IMAGES_PER_FILE=$((NUM_IMAGES / TOTAL_JOBS))
EXTRA_IMAGES=$((NUM_IMAGES % TOTAL_JOBS))

export TF_CPP_MIN_LOG_LEVEL=2
echo "Distributing ${NUM_IMAGES} image paths into ${TOTAL_JOBS} jobs."

# Divide image paths into text files for each job
for ((i=0; i<TOTAL_JOBS; i++)); do
  TEXT_FILE="${INPUT}/image_paths_$((i+1)).txt"
  if [ $i -eq $((TOTAL_JOBS - 1)) ]; then
    # For the last text file, write all remaining image paths
    tail -n +$((IMAGES_PER_FILE * i + 1)) "${IMAGE_LIST}" > "${TEXT_FILE}"
  else
    # Write the exact number of image paths per text file
    head -n $((IMAGES_PER_FILE * (i + 1))) "${IMAGE_LIST}" | tail -n ${IMAGES_PER_FILE} > "${TEXT_FILE}"
  fi
done

# Run the process on the GPUs, allowing multiple jobs per GPU
for ((i=0; i<TOTAL_JOBS; i++)); do
  GPU_INDEX=$((i % TOTAL_GPUS))
  CUDA_VISIBLE_DEVICES=${VALID_GPU_IDS[GPU_INDEX]} python ${RUN_FILE} \
    ${CONFIG_FILE} \
    ${CHECKPOINT} \
    --input "${INPUT}/image_paths_$((i+1)).txt" \
    --output-root="${OUTPUT}" &
  # Allow a short delay between starting each job to reduce system load spikes
  sleep 1
done

# Wait for all background processes to finish
wait

# Remove the image list and temporary text files
rm "${IMAGE_LIST}"
for ((i=0; i<TOTAL_JOBS; i++)); do
  rm "${INPUT}/image_paths_$((i+1)).txt"
done

# Go back to the original script's directory
cd -

echo "Processing complete." $DATA_PREFIX

