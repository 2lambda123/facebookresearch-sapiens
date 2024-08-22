from argparse import ArgumentParser
from mmengine.model import revert_sync_batchnorm
from mmseg.apis import inference_model, init_model, show_result_pyplot
import os
from tqdm import tqdm
import cv2
import numpy as np
import tempfile
from matplotlib import pyplot as plt

import torchvision
torchvision.disable_beta_transforms_warning()

def main():
    parser = ArgumentParser()
    parser.add_argument('config', help='Config file')
    parser.add_argument('checkpoint', help='Checkpoint file')
    parser.add_argument('--input', help='Input image dir')
    parser.add_argument('--output_root', '--output-root', default=None, help='Path to output dir')
    parser.add_argument('--no-save', action='store_true', help='Do not save images.')
    parser.add_argument('--seg_dir', '--seg-dir', default=None, help='Segmentation dir')
    parser.add_argument(
        '--device', default='cuda:0', help='Device used for inference')
    args = parser.parse_args()

    # build the model from a config file and a checkpoint file
    model = init_model(args.config, args.checkpoint, device=args.device)
    if args.device == 'cpu':
        model = revert_sync_batchnorm(model)

    input = args.input
    seg_dir = args.seg_dir
    image_names = []

    # Check if the input is a directory or a text file
    if os.path.isdir(input):
        input_dir = input  # Set input_dir to the directory specified in input
        image_names = [image_name for image_name in sorted(os.listdir(input_dir))
                    if image_name.endswith('.jpg') or image_name.endswith('.png')]
    elif os.path.isfile(input) and input.endswith('.txt'):
        # If the input is a text file, read the paths from it and set input_dir to the directory of the first image
        with open(input, 'r') as file:
            image_paths = [line.strip() for line in file if line.strip()]
        image_names = [os.path.basename(path) for path in image_paths]  # Extract base names for image processing
        input_dir = os.path.dirname(image_paths[0]) if image_paths else ''  # Use the directory of the first image path

    if not os.path.exists(args.output_root):
        os.makedirs(args.output_root)

    for i, image_name in tqdm(enumerate(image_names), total=len(image_names)):
        image_path = os.path.join(input_dir, image_name)
        image = cv2.imread(image_path)

        result = inference_model(model, image_path)

        result = result.pred_depth_map.data.cpu().numpy()
        pred_uv_map = result.transpose(1, 2, 0) ### (H, W, C)
        raw_pred_uv_map = np.copy(pred_uv_map)


        ## clip the pred to [-1, 1]
        pred_uv_map = np.clip(pred_uv_map, -1, 1)
        vis_pred_uv_map = (pred_uv_map + 1) / 2.0 * 255.0
        vis_pred_uv_map = vis_pred_uv_map.astype(np.uint8)
        vis_pred_uv_map_3ch = np.zeros((*vis_pred_uv_map.shape[:2], 3), dtype=np.uint8)
        vis_pred_uv_map_3ch[..., :2] = vis_pred_uv_map
        vis_pred_uv_map_3ch = cv2.cvtColor(vis_pred_uv_map_3ch, cv2.COLOR_RGB2BGR) ## convert rgb to bgr

        ##----------------------------------------
        if args.no_save is False:
            save_path = os.path.join(args.output_root, image_name.replace('.png', '.npy').replace('.jpg', '.npy').replace('.jpeg', '.npy'))
            np.save(save_path, raw_pred_uv_map) ## saved as RGB

        if seg_dir is not None:
            seg_path = os.path.join(seg_dir, image_name.replace('.png', '.npy').replace('.jpg', '.npy').replace('.jpeg', '.npy'))
            mask = np.load(seg_path)
            vis_pred_uv_map_3ch[mask == 0] = 100

        ##----------------------------------------------------
        output_file = os.path.join(args.output_root, os.path.basename(image_path))

        vis_image = np.concatenate([image, vis_pred_uv_map_3ch], axis=1)
        cv2.imwrite(output_file, vis_image)

if __name__ == '__main__':
    main()
