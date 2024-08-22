#!/bin/bash

ROOT_DIR='/mnt/ua/chencao/avatarWild/full_head_ICA'
IMAGE_DIR='2022-10-19/Chen/Segs/BodySpin/image' ## modify to change sequence

## toy data to test: 30 frames
# ROOT_DIR='/mnt/home/rawalk/drive/seg/data/full_head_ICA'
# IMAGE_DIR='2022-10-19/Chen_mini/Segs/BodySpin/image'

ICA_DIR=$ROOT_DIR/$IMAGE_DIR

## GPU settings: total jobs = jobs per gpu x number of gpus
# JOBS_PER_GPU=4; VALID_GPU_IDS="0 1 2 3 4 5 6 7" ## max parallelization
JOBS_PER_GPU=1; VALID_GPU_IDS="1"  

##------------------------------------------------------------
./0_pose.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS &
wait

./1_seg.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS &
wait

./2_depth.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS &
wait

./3_normal.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS &
wait

./4_albedo.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS & ## face only albedo
# ./4_albedo_render_people.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS & ## full body albedo
wait

./5_hdri.sh $ICA_DIR $JOBS_PER_GPU $VALID_GPU_IDS &
wait

./6_make_video.sh $ICA_DIR
