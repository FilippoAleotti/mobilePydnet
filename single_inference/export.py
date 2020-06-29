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

"""
Export a trained tensorflow model into various formats.
Outputs:
    mlmodel: for ios devices
    tflite: for android devices
    pb: protobuffer, for generic purposes
"""
import sys

sys.path.insert(0, ".")
import tensorflow as tf
import os
import argparse
from tensorflow.python.framework import graph_util
from tensorflow.python.platform import gfile
from tensorflow.python.tools import freeze_graph
from tensorflow.python.tools import optimize_for_inference_lib
from tensorflow.python.saved_model import tag_constants
import network
import tfcoreml
import coremltools
import coremltools.proto.FeatureTypes_pb2 as ft

tf_version = int(tf.__version__.replace(".", ""))
if tf_version < 1140:
    raise ValueError("For this script, tensorflow must be greater or equal to 1.14.0")

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.ERROR)
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

parser = argparse.ArgumentParser(description="Freeze your network")
parser.add_argument("--ckpt", type=str, help="which checkpoint freeze?", required=True)
parser.add_argument("--arch", type=str, help="network to freeze", required=True)
parser.add_argument(
    "--dest", type=str, help="where to save frozen models", required=True
)
parser.add_argument("--height", type=int, default=384, help="height of image")
parser.add_argument("--width", type=int, default=640, help="width of image")
parser.add_argument(
    "--debug", action="store_true", help="active debug and visualize graph nodes"
)
args = parser.parse_args()


def main(_):
    params = {
        "arch": args.arch,
        "output": os.path.join(args.dest, "frozen_models"),
        "protobuf": "frozen_" + args.arch + ".pb",
        "pbtxt": args.arch + ".pbtxt",
        "ckpt": args.arch + ".ckpt",
        "mlmodel": args.arch + ".mlmodel",
        "onnx": args.arch + ".onnx",
        "input_saver_def_path": "",
        "input_binary": False,
        "restore_op": "save/restore_all",
        "saving_op": "save/Const:0",
        "frozen_graph_name": "frozen_" + args.arch + ".pb",
        "optimized_graph_name": "optimized_" + args.arch + ".pb",
        "optimized_tflite_name": "tflite_" + args.arch + ".tflite",
        "clear_devices": True,
    }

    if not os.path.exists(params["output"]):
        os.makedirs(params["output"])

    with tf.Graph().as_default():

        network_params = {
            "height": args.height,
            "width": args.width,
            "is_training": False,
        }
        input_node = "im0"
        input_tensor = tf.placeholder(
            tf.float32,
            [1, network_params["height"], network_params["width"], 3],
            name="im0",
        )
        model = network.Pydnet(network_params)
        predictions = model.forward(input_tensor)
        params["output_nodes_port"] = [x.name for x in model.output_nodes]
        params["output_nodes"] = [
            out.name.replace(":0", "") for out in model.output_nodes
        ]
        print("=> output nodes port: {}".format(params["output_nodes_port"]))
        print("=> output nodes: {}".format(params["output_nodes"]))
        params["input_nodes"] = [input_node]
        saver = tf.train.Saver()
        with tf.Session() as sess:
            saver.restore(sess, args.ckpt)

            if args.debug:
                for tensor in [
                    n.name for n in tf.get_default_graph().as_graph_def().node
                ]:
                    print(tensor)

            tf.train.write_graph(sess.graph_def, params["output"], params["pbtxt"])
            graph_pbtxt = os.path.join(params["output"], params["pbtxt"])
            graph_path = os.path.join(params["output"], params["ckpt"])
            saver.save(sess, graph_path)

            outputs = params["output_nodes"][0]
            for name in params["output_nodes"][1:]:
                outputs += "," + name

            frozen_graph_path = os.path.join(
                params["output"], params["frozen_graph_name"]
            )
            freeze_graph.freeze_graph(
                graph_pbtxt,
                params["input_saver_def_path"],
                params["input_binary"],
                graph_path,
                outputs,
                params["restore_op"],
                params["saving_op"],
                frozen_graph_path,
                params["clear_devices"],
                "",
            )

            converter = tf.lite.TFLiteConverter.from_frozen_graph(
                frozen_graph_path, params["input_nodes"], params["output_nodes"]
            )
            tflite_model = converter.convert()
            optimized_tflite_path = os.path.join(
                params["output"], params["optimized_tflite_name"]
            )
            with open(optimized_tflite_path, "wb") as f:
                f.write(tflite_model)

    mlmodel_path = os.path.join(params["output"], params["mlmodel"])
    mlmodel = tfcoreml.convert(
        tf_model_path=frozen_graph_path,
        mlmodel_path=mlmodel_path,
        output_feature_names=params["output_nodes_port"],
        image_input_names=["im0:0"],
        input_name_shape_dict={
            "im0:0": [1, network_params["height"], network_params["width"], 3]
        },
        minimum_ios_deployment_target="12",
        image_scale=1 / 255.0,
    )

    print("=> setting up input and output of coreml model")
    # NOTE: at this point, outputs are MultiArray objects. Instead,
    # we have to convert them as GRAYSCALE image
    spec = coremltools.utils.load_spec(mlmodel_path)
    for output in spec.description.output:
        array_shape = tuple(output.type.multiArrayType.shape)
        channels, height, width = array_shape
        output.type.imageType.colorSpace = ft.ImageFeatureType.ColorSpace.Value(
            "GRAYSCALE"
        )
        output.type.imageType.width = width
        output.type.imageType.height = height

    updated_model = coremltools.models.MLModel(spec)
    updated_model.author = "Filippo Aleotti"
    updated_model.license = "Apache v2"
    updated_model.short_description = params["arch"]
    updated_model.save(mlmodel_path)

    print("Done!")


if __name__ == "__main__":
    tf.app.run()
