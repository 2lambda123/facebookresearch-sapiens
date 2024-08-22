from argparse import ArgumentParser
import os
from tqdm import tqdm
import cv2
import numpy as np
from utils import *



##--------------------------------------------------
def main():
    parser = ArgumentParser()
    parser.add_argument('--data_dir', help='Test data dir')
    parser.add_argument('--pred_dir', '--pred-dir', default=None, help='Path to output dir')
    args = parser.parse_args()

    data_dir = args.data_dir
    pred_dir = args.pred_dir

    ##=-------------for thuman2------------------
    gt_face_dir = os.path.join(data_dir, 'face')
    gt_full_body_dir = os.path.join(data_dir, 'full_body')
    gt_upper_half_dir = os.path.join(data_dir, 'upper_half')

    pred_face_dir = os.path.join(pred_dir, 'face', 'rgb')
    pred_full_body_dir = os.path.join(pred_dir, 'full_body', 'rgb')
    pred_upper_half_dir = os.path.join(pred_dir, 'upper_half', 'rgb')

    print(pred_dir)
    print('face:')
    face_metrics = depth_evaluate(gt_face_dir, pred_face_dir)
    print_metrics(face_metrics)
    print()

    print('full_body_metrics:')
    full_body_metrics = depth_evaluate(gt_full_body_dir, pred_full_body_dir)
    print_metrics(full_body_metrics)
    print()

    print('upper_half_metrics:')
    upper_half_metrics = depth_evaluate(gt_upper_half_dir, pred_upper_half_dir)
    print_metrics(upper_half_metrics)
    print()


if __name__ == '__main__':
    main()
