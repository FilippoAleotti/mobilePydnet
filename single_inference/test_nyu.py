"""
Evaluate the model using NYU v2 dataset
- download splits.mat file from http://horatio.cs.nyu.edu/mit/silberman/indoor_seg_sup/splits.mat
- download dataset from http://horatio.cs.nyu.edu/mit/silberman/nyu_depth_v2/nyu_depth_v2_labeled.mat
"""
import argparse
import os

import cv2
import h5py
import numpy as np
import tensorflow as tf
from scipy.io import loadmat
from tqdm import tqdm

from eval_utils import compute_errors, compute_scale_and_shift
from network import Pydnet

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"


class NYUDataloader:
    """Dataloader for NYU v2"""

    def __init__(self, params):
        self.params = params
        self.height = params["height"]
        self.width = params["width"]
        self.img_dir = params["labels"]
        self.labels_file = params["splits"]
        self.num_workers = 1
        self.num_samples = 0

    def preprocess(self, img0):
        """Prepare single image at testing time"""
        img0 = tf.image.resize_images(img0, [self.height, self.width], tf.image.ResizeMethod.AREA)
        img0.set_shape([self.height, self.width, 3])
        img0 = img0 / 255.0
        return img0

    def create_iterator(self, num_parallel_calls=4):
        self.nyu_generator = NYUGenerator(self.img_dir, self.labels_file)
        dataset = tf.data.Dataset.from_generator(
            self.nyu_generator,
            output_types=tf.float32,
            output_shapes=[480, 640, 3],
        )
        dataset = dataset.map(self.preprocess, num_parallel_calls=num_parallel_calls)
        dataset = dataset.batch(1)
        dataset = dataset.repeat()
        iterator = dataset.make_initializable_iterator()
        return iterator


class NYUGenerator:
    """
    Read NYU testing split from mat files
    Adapted from https://gist.github.com/ranftlr/a1c7a24ebb24ce0e2f2ace5bce917022
    """

    def __init__(self, data_path, label_file):
        if not os.path.exists(data_path):
            raise ValueError(f"Cannot find {data_path}")
        if not os.path.exists(label_file):
            raise ValueError(f"Cannot find {label_file}")
        self.data_path = data_path
        self.label_file = label_file

    def __call__(self):
        mat = loadmat(self.label_file)
        indices = [ind[0] - 1 for ind in mat["testNdxs"]]

        with h5py.File(self.data_path, "r") as f:
            for ind in indices:
                yield np.swapaxes(f["images"][ind], 0, 2)

    def read_gt_files(self):
        """Load ground truth maps
        Adapted from https://gist.github.com/ranftlr/a1c7a24ebb24ce0e2f2ace5bce917022
        """
        depth_list = []
        name_list = []

        mat = loadmat(self.label_file)
        indices = [ind[0] - 1 for ind in mat["testNdxs"]]

        with h5py.File(self.data_path, "r") as f:
            for ind in indices:
                name_list.append(str(ind))
                depth_list.append(np.swapaxes(f["rawDepths"][ind], 0, 1))
        return name_list, depth_list


def run_inference(opts):
    """Run the model on NYU v2 dataset"""
    network_params = {"height": 320, "width": 640, "is_training": False}
    dataset_params = {"height": 320, "width": 640, "labels": opts.labels, "splits": opts.splits}
    dataset = NYUDataloader(dataset_params)
    num_elements = 654

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

    with tqdm(total=num_elements) as pbar:
        for i in range(num_elements):
            idepth = sess.run(predicted_idepth)
            idepth = np.squeeze(idepth)
            min_idepth = idepth.min()
            max_idepth = idepth.max()
            norm_idepth = (idepth - min_idepth) / (max_idepth - min_idepth)
            norm_idepth *= 255.0

            norm_idepth = cv2.resize(norm_idepth, (640, 480))  # nyu images are 640x480
            img_path = os.path.join(opts.dest, f"{str(i).zfill(4)}.png")
            cv2.imwrite(img_path, (norm_idepth * 256.0).astype(np.uint16))
            pbar.update(1)
    print("Inference done!")


def eval(opts):
    """Compute error metrics."""
    nyu = NYUGenerator(data_path=opts.labels, label_file=opts.splits)
    errors = []
    test_images, gt_depths = nyu.read_gt_files()

    with tqdm(total=len(test_images)) as pbar:
        for index in range(len(test_images)):
            test_img = f"{str(index).zfill(4)}.png"
            target = gt_depths[index]

            pred_path = os.path.join(opts.dest, test_img)
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

            pbar.update(1)

    mean_errors = np.array(errors).mean(0)
    labels = ["abs_rel", "sq_rel", "rmse", "rmse_log", "a1", "a2", "a3"]
    for i in range(len(labels)):
        print(f"{labels[i]}:{mean_errors[i]}")

    print("Evaluation done!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate depth network on NYU v2")
    parser.add_argument("--ckpt", type=str, help="path to checkpoint", required=True)
    parser.add_argument(
        "--labels", type=str, help="path to dataset", default="nyu_depth_v2_labeled.mat"
    )
    parser.add_argument("--splits", type=str, help="path to splits", default="splits.mat")
    parser.add_argument("--dest", type=str, help="prediction folder", default="nyu")
    parser.add_argument("--max_depth", type=float, help="maximum depth value", default=10.0)

    opts = parser.parse_args()

    run_inference(opts)
    eval(opts)
