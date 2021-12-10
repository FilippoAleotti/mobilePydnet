"""
Evaluate the model using Eigen split of KITTI dataset
- prepare gt depth running the script https://github.com/nianticlabs/monodepth2/blob/master/export_gt_depth.py
"""
import argparse
import os

import cv2
import numpy as np
import tensorflow as tf
from tqdm import tqdm

from eval_utils import compute_errors, compute_scale_and_shift
from network import Pydnet

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"


class KITTILoader(object):
    def __init__(self, params):
        self.params = params
        self.height = params["height"]
        self.width = params["width"]
        self.data_list_file = params["data_list_file"]
        self.data_path = params["data_path"]
        self.num_workers = 4
        self.data_list = np.loadtxt(self.data_list_file, dtype=bytes).astype(np.str)
        self.default_img_shape = None

    def read_and_decode(self, filename_queue):
        """Read jpeg file from file system"""
        img0_name = tf.strings.join([self.data_path, "/", filename_queue, ".jpg"])
        img0 = tf.image.decode_jpeg(tf.io.read_file(img0_name), channels=3)
        img0 = tf.cast(img0, tf.float32)
        return img0

    def preprocess(self, filename_queue):
        """Prepare single image at testing time"""
        img0 = self.read_and_decode(filename_queue)
        img0 = tf.image.resize_images(img0, [self.height, self.width], tf.image.ResizeMethod.AREA)
        img0.set_shape([self.height, self.width, 3])
        img0 = img0 / 255.0
        return img0

    def create_iterator(self, num_parallel_calls=4):
        """Create iterator"""
        data_list = tf.convert_to_tensor(self.data_list, dtype=tf.string)
        dataset = tf.data.Dataset.from_tensor_slices(data_list)
        dataset = dataset.map(self.preprocess, num_parallel_calls=num_parallel_calls)
        dataset = dataset.batch(1)
        dataset = dataset.repeat()
        iterator = dataset.make_initializable_iterator()
        return iterator


def read_test_files(test_file) -> list:
    """Read test files from txt file"""
    assert os.path.exists(test_file)
    with open(test_file, "r") as f:
        lines = f.readlines()
    lines = [l.strip() for l in lines]
    return lines


def run_inference(opts):
    """Run the model on KITTI"""
    network_params = {"height": 320, "width": 640, "is_training": False}
    dataset_params = {
        "height": 320,
        "width": 640,
        "data_path": opts.data_path,
        "data_list_file": opts.data_list_file,
    }
    dataset = KITTILoader(dataset_params)

    iterator = dataset.create_iterator()
    batch_img = iterator.get_next()

    network = Pydnet(network_params)
    predicted_idepth = network.forward(batch_img)
    predicted_idepth = tf.nn.relu(predicted_idepth)

    # restore graph
    saver = tf.train.Saver()
    sess = tf.Session()
    sess.run(tf.compat.v1.global_variables_initializer())
    sess.run(iterator.initializer)
    saver.restore(sess, opts.ckpt)

    os.makedirs(opts.dest, exist_ok=True)
    test_images = read_test_files(opts.data_list_file)
    num_images = len(test_images)
    with tqdm(total=num_images) as pbar:
        for i in range(num_images):
            idepth = sess.run(predicted_idepth)
            idepth = np.squeeze(idepth)
            min_idepth = idepth.min()
            max_idepth = idepth.max()
            norm_idepth = (idepth - min_idepth) / (max_idepth - min_idepth)
            norm_idepth *= 255.0

            target_path = os.path.join(opts.data_path, f"{test_images[i]}.jpg")
            target = cv2.imread(target_path)
            h, w = target.shape[:2]
            norm_idepth = cv2.resize(norm_idepth, (w, h))

            img_path = os.path.join(opts.dest, f"{str(i).zfill(4)}.png")
            cv2.imwrite(img_path, (norm_idepth * 256.0).astype(np.uint16))
            pbar.update(1)
    print("Inference done!")


def eval(opts):
    """Compute error metrics."""
    errors = []
    test_images = read_test_files(opts.data_list_file)
    print("=> loading gt data")
    gt_depths = np.load(opts.gt_path, fix_imports=True, encoding="latin1", allow_pickle=True)[
        "data"
    ]
    print("=> starting evaluation")
    with tqdm(total=len(test_images)) as pbar:
        for i in range(len(test_images)):
            target = gt_depths[i]
            pred_path = os.path.join(opts.dest, f"{str(i).zfill(4)}.png")
            prediction_idepth = cv2.imread(pred_path, -1) / 256.0

            mask = (target > 1e-3) & (target < opts.max_depth)

            target_idepth = np.zeros_like(target)
            target_idepth[mask == 1] = 1.0 / target[mask == 1]
            scale, shift = compute_scale_and_shift(prediction_idepth, target_idepth, mask)
            prediction_idepth_aligned = scale * prediction_idepth + shift

            disparity_cap = 1.0 / opts.max_depth
            prediction_idepth_aligned[prediction_idepth_aligned < disparity_cap] = disparity_cap
            prediciton_depth_aligned = 1.0 / prediction_idepth_aligned

            prediciton_depth_aligned = prediciton_depth_aligned[mask == 1]
            target = target[mask == 1]
            errors.append(compute_errors(target, prediciton_depth_aligned))

            pbar.update(1)

    mean_errors = np.array(errors).mean(0)
    labels = ["abs_rel", "sq_rel", "rmse", "rmse_log", "a1", "a2", "a3"]
    for i in range(len(labels)):
        print(f"{labels[i]}:{mean_errors[i]}")

    print("Evaluation done!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate depth network on KITTI")
    parser.add_argument("--ckpt", type=str, help="path to checkpoint", required=True)
    parser.add_argument("--data_path", type=str, help="path to kitti", required=True)
    parser.add_argument("--gt_path", type=str, help="path to gt_depths.npz", required=True)
    parser.add_argument(
        "--data_list_file", type=str, help="path to data list", default="test_kitti.txt"
    )
    parser.add_argument("--dest", type=str, help="prediction folder", default="kitti")
    parser.add_argument("--max_depth", type=float, help="maximum depth value", default=80.0)
    opts = parser.parse_args()

    run_inference(opts)
    eval(opts)
