#
# MIT License
#
# Copyright (c) 2018 Matteo Poggi m.poggi@unibo.it
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# adapted from https://github.com/mattpoggi/pydnet/blob/master/pydnet.py
import tensorflow as tf
from modules import conv2d_leaky, bilinear_upsampling_by_convolution


class Pydnet(object):
    def __init__(self, params):
        self.params = params
        self.height = params["height"]
        self.width = params["width"]
        self.is_training = params["is_training"]
        self.output_nodes = None

        if self.is_training:
            self.scales = params["scales"]

    def forward(self, input_image):
        """ Single forward of the network
        """
        encoder_features = self.encoder(input_image)
        predictions = self.decoder(encoder_features)
        if not self.is_training:
            # NOTE: set up nodes for mobile app
            self.output_nodes = [self.make_visual(predictions)]
        return predictions

    def make_visual(self, prediction):
        prediction = tf.nn.relu(prediction)
        min_depth = tf.reduce_min(prediction)
        max_depth = tf.reduce_max(prediction)
        prediction = (prediction - min_depth) / (max_depth - min_depth)
        return prediction

    def encoder(self, input_image):
        """ Create PyDNet feature extractor
        """
        with tf.variable_scope("encoder"):
            features = []
            features.append(input_image)
            with tf.variable_scope("conv1a"):
                conv1a = conv2d_leaky(input_image, [3, 3, 3, 16], [16], 2, True)
            with tf.variable_scope("conv1b"):
                conv1b = conv2d_leaky(conv1a, [3, 3, 16, 16], [16], 1, True)

            features.append(conv1b)

            with tf.variable_scope("conv2a"):
                conv2a = conv2d_leaky(conv1b, [3, 3, 16, 32], [32], 2, True)
            with tf.variable_scope("conv2b"):
                conv2b = conv2d_leaky(conv2a, [3, 3, 32, 32], [32], 1, True)

            features.append(conv2b)

            with tf.variable_scope("conv3a"):
                conv3a = conv2d_leaky(conv2b, [3, 3, 32, 64], [64], 2, True)
            with tf.variable_scope("conv3b"):
                conv3b = conv2d_leaky(conv3a, [3, 3, 64, 64], [64], 1, True)

            features.append(conv3b)

            with tf.variable_scope("conv4a"):
                conv4a = conv2d_leaky(conv3b, [3, 3, 64, 96], [96], 2, True)
            with tf.variable_scope("conv4b"):
                conv4b = conv2d_leaky(conv4a, [3, 3, 96, 96], [96], 1, True)

            features.append(conv4b)

            with tf.variable_scope("conv5a"):
                conv5a = conv2d_leaky(conv4b, [3, 3, 96, 128], [128], 2, True)
            with tf.variable_scope("conv5b"):
                conv5b = conv2d_leaky(conv5a, [3, 3, 128, 128], [128], 1, True)

            features.append(conv5b)

            with tf.variable_scope("conv6a"):
                conv6a = conv2d_leaky(conv5b, [3, 3, 128, 192], [192], 2, True)
            with tf.variable_scope("conv6b"):
                conv6b = conv2d_leaky(conv6a, [3, 3, 192, 192], [192], 1, True)

            features.append(conv6b)
            return features

    def decoder(self, encoder_features):
        """ Create PyDNet decoder
        """
        with tf.variable_scope("decoder"):
            with tf.variable_scope("L6") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv6 = self.build_estimator(encoder_features[6])
                    prediction_6 = self.get_disp(conv6)
                with tf.variable_scope("upsampler") as scope:
                    upconv6 = bilinear_upsampling_by_convolution(conv6)
            # SCALE 5
            with tf.variable_scope("L5") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv5 = self.build_estimator(encoder_features[5], upconv6)
                    prediction_5 = self.get_disp(conv5)
                with tf.variable_scope("upsampler") as scope:
                    upconv5 = bilinear_upsampling_by_convolution(conv5)
            # SCALE 4
            with tf.variable_scope("L4") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv4 = self.build_estimator(encoder_features[4], upconv5)
                    prediction_4 = self.get_disp(conv4)
                with tf.variable_scope("upsampler") as scope:
                    upconv4 = bilinear_upsampling_by_convolution(conv4)
            # SCALE 3
            with tf.variable_scope("L3") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv3 = self.build_estimator(encoder_features[3], upconv4)
                    prediction_3 = self.get_disp(conv3)
                with tf.variable_scope("upsampler") as scope:
                    upconv3 = bilinear_upsampling_by_convolution(conv3)
            # SCALE 2
            with tf.variable_scope("L2") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv2 = self.build_estimator(encoder_features[2], upconv3)
                    prediction_2 = self.get_disp(conv2)
                with tf.variable_scope("upsampler") as scope:
                    upconv2 = bilinear_upsampling_by_convolution(conv2)
            # SCALE 1
            with tf.variable_scope("L1") as scope:
                with tf.variable_scope("estimator") as scope:
                    conv1 = self.build_estimator(encoder_features[1], upconv2)
                    prediction_1 = self.get_disp(conv1)

            size = [self.height, self.width]

            if not self.is_training:
                with tf.variable_scope("half"):
                    prediction_1 = tf.image.resize_images(prediction_1, size)
                return prediction_1

            prediction_1 = tf.image.resize_images(prediction_1, size)
            prediction_2 = tf.image.resize_images(prediction_2, size)
            prediction_3 = tf.image.resize_images(prediction_3, size)

            return [prediction_1, prediction_2, prediction_3]

    def get_disp(self, x):
        """ Get disparity
        """
        with tf.variable_scope("get_disp"):
            disp = conv2d_leaky(x, [3, 3, x.shape[3], 1], [1], 1, False)
            return disp

    # Single scale estimator
    def build_estimator(self, features, upsampled_disp=None):
        """
            Create single scale estimator
        """
        with tf.variable_scope("build_estimator"):
            if upsampled_disp is not None:
                disp2 = tf.concat([features, upsampled_disp], -1)
            else:
                disp2 = features
            with tf.variable_scope("disp-3") as scope:
                disp3 = conv2d_leaky(disp2, [3, 3, disp2.shape[3], 96], [96], 1, True)
            with tf.variable_scope("disp-4") as scope:
                disp4 = conv2d_leaky(disp3, [3, 3, disp3.shape[3], 64], [64], 1, True)
            with tf.variable_scope("disp-5") as scope:
                disp5 = conv2d_leaky(disp4, [3, 3, disp4.shape[3], 32], [32], 1, True)
            with tf.variable_scope("disp-6") as scope:
                disp6 = conv2d_leaky(
                    disp5, [3, 3, disp5.shape[3], 8], [8], 1, True
                )  # 8 channels for compatibility with @other@ devices
            return disp6
