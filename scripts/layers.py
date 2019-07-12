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

import tensorflow as tf

# Hand-made leaky relu
def leaky_relu(x, alpha=0.2):
  return tf.maximum(x, alpha * x)

# 2D convolution wrapper
def conv2d_leaky(x, kernel_shape, bias_shape, strides=1, relu=True, padding='SAME'):
  # Conv2D
  weights = tf.get_variable("weights", kernel_shape, initializer=tf.contrib.layers.xavier_initializer(), dtype=tf.float32)
  biases = tf.get_variable("biases", bias_shape, initializer=tf.truncated_normal_initializer(), dtype=tf.float32)
  output = tf.nn.conv2d(x, weights, strides=[1, strides, strides, 1], padding=padding)
  output = tf.nn.bias_add(output, biases)
  # ReLU (if required)
  if relu:
    output = leaky_relu(output, 0.2)
  return output

# 2D deconvolution wrapper
def deconv2d_leaky(x, kernel_shape, bias_shape, strides=1, relu=True, padding='SAME'):
  # Conv2D
  weights = tf.get_variable("weights", kernel_shape, initializer=tf.contrib.layers.xavier_initializer(), dtype=tf.float32)
  biases = tf.get_variable("biases", bias_shape, initializer=tf.truncated_normal_initializer(), dtype=tf.float32)
  x_shape = tf.shape(x)
  outputShape = [x_shape[0],x_shape[1]*strides,x_shape[2]*strides,kernel_shape[2]]  
  output = tf.nn.conv2d_transpose(x, weights, output_shape=outputShape, strides=[1, strides, strides, 1], padding=padding)
  output = tf.nn.bias_add(output, biases)
  # ReLU (if required)
  if relu:
    output = leaky_relu(output, 0.2)
  return output    