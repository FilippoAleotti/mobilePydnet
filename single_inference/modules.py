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

# From https://github.com/mattpoggi/pydnet/blob/master/layers.py

from __future__ import division
import tensorflow as tf
import numpy as np
import math


def leaky_relu(x, alpha=0.2):
    return tf.nn.leaky_relu(x, alpha=alpha)


####################################################################################################################################
# 2D convolution wrapper
####################################################################################################################################
def conv2d_leaky(
    input, kernel_shape, bias_shape, strides=1, relu=True, padding="SAME", dil=1
):
    # Conv2D
    weights = tf.get_variable(
        "weights",
        kernel_shape,
        initializer=tf.contrib.layers.xavier_initializer(),
        dtype=tf.float32,
    )
    biases = tf.get_variable(
        "biases",
        bias_shape,
        initializer=tf.truncated_normal_initializer(),
        dtype=tf.float32,
    )
    output = tf.nn.conv2d(
        input,
        weights,
        strides=[1, strides, strides, 1],
        padding=padding,
        dilations=[1, dil, dil, 1],
    )
    output = tf.nn.bias_add(output, biases)

    # ReLU (if required)
    if relu == False:
        return output

    output = leaky_relu(output, 0.2)
    return output


def deconv2d_leaky(
    input, kernel_shape, bias_shape, outputShape, strides=1, relu=True, padding="SAME"
):

    # Conv2D
    weights = tf.get_variable(
        "weights",
        kernel_shape,
        initializer=tf.contrib.layers.xavier_initializer(),
        dtype=tf.float32,
    )
    biases = tf.get_variable(
        "biases",
        bias_shape,
        initializer=tf.truncated_normal_initializer(),
        dtype=tf.float32,
    )
    output = tf.nn.conv2d_transpose(
        input,
        weights,
        output_shape=outputShape,
        strides=[1, strides, strides, 1],
        padding=padding,
    )
    output = tf.nn.bias_add(output, biases)

    # ReLU (if required)
    if relu == False:
        print("WARNING: reLU disabled")
    else:
        output = leaky_relu(output, 0.2)
    return output


####################################################################################################################################
# 2D convolution wrapper
####################################################################################################################################
def dilated_conv2d_leaky(
    input, kernel_shape, bias_shape, name, rate=1, relu=True, padding="SAME"
):
    with tf.variable_scope(name):
        # Conv2D
        weights = tf.get_variable(
            "weights", kernel_shape, initializer=tf.contrib.layers.xavier_initializer()
        )
        biases = tf.get_variable(
            "biases", bias_shape, initializer=tf.truncated_normal_initializer()
        )
        output = tf.nn.atrous_conv2d(input, weights, rate=rate, padding=padding)
        output = tf.nn.bias_add(output, biases)

        if relu == False:
            print("WARNING: reLU disabled")
        else:
            output = leaky_relu(output, 0.2)
    return output


def bilinear_upsampling_by_deconvolution(src):
    shape = src.get_shape().as_list()
    h = shape[1] * 2
    w = shape[2] * 2
    return deconv2d_leaky(
        src, [2, 2, shape[3], shape[3]], shape[3], [shape[0], h, w, shape[3]], 2, True
    )


def bilinear_upsampling_by_convolution(src):
    with tf.variable_scope("bilinear_upsampling_by_convolution"):
        shape = src.get_shape().as_list()
        height = shape[1] * 2
        width = shape[2] * 2
        channels = shape[3]
        upsampled_src = tf.image.resize_images(src, [height, width])
        upsampled_src = conv2d_leaky(
            upsampled_src, [2, 2, channels, channels], [channels]
        )
        return upsampled_src
