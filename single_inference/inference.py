# Copyright 2020 Filippo Aleotti
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import tensorflow as tf
import cv2
import numpy as np
import os
import argparse
import glob
from tqdm import tqdm
import matplotlib.pyplot as plt
import network
from tensorflow.python.util import deprecation

# disable future warnings and info messages for this demo
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.ERROR)

parser = argparse.ArgumentParser(description="Single shot depth estimator")
parser.add_argument(
    "--img", type=str, help="path to reference RGB image", required=True
)
parser.add_argument("--ckpt", type=str, help="path to checkpoint", required=True)
parser.add_argument("--cpu", action="store_true", help="run on cpu")
parser.add_argument(
    "--original_size", action="store_true", help="if true, restore original image size"
)
parser.add_argument(
    "--dest",
    type=str,
    help="path to result folder. If not exists, it will be created",
    default="results",
)

opts = parser.parse_args()
if opts.cpu:
    os.environ["CUDA_VISIBLE_DEVICES"] = "-1"


def create_dir(d):
    """ Create a directory if it does not exist
    Args:
        d: directory to create
    """
    if not os.path.exists(d):
        os.makedirs(d)


def main(_):
    network_params = {"height": 320, "width": 640, "is_training": False}

    if os.path.isfile(opts.img):
        img_list = [opts.img]
    elif os.path.isdir(opts.img):
        img_list = glob.glob(os.path.join(opts.img, "*.{}".format("png")))
        img_list = sorted(img_list)
        if len(img_list) == 0:
            raise ValueError("No {} images found in folder {}".format(".png", opts.img))
        print("=> found {} images".format(len(img_list)))
    else:
        raise Exception("No image nor folder provided")

    model = network.Pydnet(network_params)
    tensor_image = tf.placeholder(tf.float32, shape=(320, 640, 3))
    batch_img = tf.expand_dims(tensor_image, 0)
    tensor_depth = model.forward(batch_img)
    tensor_depth = tf.nn.relu(tensor_depth)

    # restore graph
    saver = tf.train.Saver()
    sess = tf.Session()
    sess.run(tf.global_variables_initializer())
    saver.restore(sess, opts.ckpt)

    # run graph
    for i in tqdm(range(len(img_list))):

        # preparing image
        img = cv2.imread(img_list[i])
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        h, w, _ = img.shape
        img = cv2.resize(img, (640, 320))
        img = img / 255.0

        # inference
        depth = sess.run(tensor_depth, feed_dict={tensor_image: img})
        depth = np.squeeze(depth)
        min_depth = depth.min()
        max_depth = depth.max()
        depth = (depth - min_depth) / (max_depth - min_depth)
        depth *= 255.0

        # preparing final depth
        if opts.original_size:
            depth = cv2.resize(depth, (w, h))
        name = os.path.basename(img_list[i]).split(".")[0]
        dest = opts.dest
        create_dir(dest)
        dest = os.path.join(dest, name + "_depth.png")
        plt.imsave(dest, depth, cmap="magma")


if __name__ == "__main__":
    tf.app.run()
