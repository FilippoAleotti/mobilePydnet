"""
Evaluate the model using TUM dataset
- run the script https://github.com/google/mannequinchallenge/blob/master/fetch_tum_data.sh
"""
import argparse
import os

import cv2
import h5py
import numpy as np
import tensorflow as tf
from tqdm import tqdm

from eval_utils import compute_errors, compute_scale_and_shift
from network import Pydnet

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"


class TUMDataloader:
    """Test TUM dataset"""

    def __init__(self, params):
        self.params = params
        self.height = params["height"]
        self.width = params["width"]
        self.data_path = params["data_path"]
        self.num_workers = 4
        self.data_list_file = params["data_list_file"]
        self.data_list = np.loadtxt(self.data_list_file, dtype=bytes).astype(np.str)
        self.default_img_shape = [384, 512, 3]

    def preprocess(self, img0):
        """Prepare single image at testing time"""
        img0 = tf.image.resize_images(img0, [self.height, self.width], tf.image.ResizeMethod.AREA)
        img0.set_shape([self.height, self.width, 3])
        return img0

    def create_iterator(self, num_parallel_calls=4):
        """ """
        self.tum_generator = TUMGenerator(self.data_path, self.data_list)
        dataset = tf.data.Dataset.from_generator(
            self.tum_generator,
            output_types=tf.float32,
            output_shapes=self.default_img_shape,
        )
        dataset = dataset.map(self.preprocess, num_parallel_calls=num_parallel_calls)
        dataset = dataset.batch(1)
        dataset = dataset.repeat()
        iterator = dataset.make_initializable_iterator()
        return iterator


class TUMGenerator:
    def __init__(self, data_path, test_files):
        self.data_path = data_path
        self.test_files = test_files

    def __call__(self):
        for f in self.test_files:
            test_img_path = os.path.join(self.data_path, f)
            with h5py.File(test_img_path, "r") as test_img:
                img = test_img.get("/gt/img_1")
                img = np.float32(np.array(img))
                yield img

    def read_gt_files(self):
        targets = {}
        samples = None
        with open(self.test_files, "r") as f:
            samples = f.readlines()

        for sample in samples:
            sample = sample.strip()
            test_img_path = os.path.join(self.data_path, sample)
            name = sample.replace(".jpg.h5", "")
            with h5py.File(test_img_path, "r") as test_img_h5:
                target = test_img_h5.get("/gt/gt_depth")
                target = np.float32(np.array(target))
                targets[name] = target
        return targets


def run_inference(opts):
    """Run the model on TUM dataset"""
    network_params = {"height": 320, "width": 640, "is_training": False}
    dataset_params = {
        "height": 320,
        "width": 640,
        "data_path": opts.data_path,
        "data_list_file": opts.data_list_file,
    }
    dataset = TUMDataloader(dataset_params)

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

    names = None
    with open(opts.data_list_file, "r") as f:
        names = f.readlines()
    names = [n.strip().replace(".jpg.h5", "") for n in names]
    num_lines = len(names)

    with tqdm(total=num_lines) as pbar:
        for i in range(num_lines):
            idepth = sess.run(predicted_idepth)
            idepth = np.squeeze(idepth)
            min_idepth = idepth.min()
            max_idepth = idepth.max()
            norm_idepth = (idepth - min_idepth) / (max_idepth - min_idepth)
            norm_idepth *= 255.0

            norm_idepth = cv2.resize(norm_idepth, (512, 384))
            img_path = os.path.join(opts.dest, f"{names[i]}.png")
            cv2.imwrite(img_path, (norm_idepth * 256.0).astype(np.uint16))
            pbar.update(1)
    print("Inference done!")


def eval(opts):
    """Compute error metrics."""
    tum = TUMGenerator(data_path=opts.data_path, test_files=opts.data_list_file)
    errors = []
    gt_depths = tum.read_gt_files()
    num_lines = sum(1 for _ in open(opts.data_list_file, "r"))

    with open(opts.data_list_file, "r") as f:
        for sample in tqdm(f, total=num_lines):
            sample = sample.strip().replace(".jpg.h5", "")
            target = gt_depths[sample]
            pred_path = os.path.join(opts.dest, f"{sample}.png")
            prediction_idepth = cv2.imread(pred_path, -1) / 256.0

            mask = (target > 0) & (target < opts.max_depth)
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

    mean_errors = np.array(errors).mean(0)
    labels = ["abs_rel", "sq_rel", "rmse", "rmse_log", "a1", "a2", "a3"]
    for i in range(len(labels)):
        print(f"{labels[i]}:{mean_errors[i]}")

    print("Evaluation done!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate depth network on TUM")
    parser.add_argument("--ckpt", type=str, help="path to checkpoint", required=True)
    parser.add_argument("--data_path", type=str, help="path to TUM data", required=True)
    parser.add_argument(
        "--data_list_file", type=str, help="path to list files", default="test_tum.txt"
    )
    parser.add_argument("--dest", type=str, help="prediction folder", default="tum")
    parser.add_argument("--max_depth", type=float, help="maximum depth value", default=10.0)

    opts = parser.parse_args()

    run_inference(opts)
    eval(opts)
