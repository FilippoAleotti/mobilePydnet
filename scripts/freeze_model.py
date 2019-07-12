'''
Freeze a tensorflow model
'''

import tensorflow as tf
import sys
import os
import argparse
from tensorflow.python.framework import graph_util
from tensorflow.python.platform import gfile
from tensorflow.python.tools import freeze_graph
from tensorflow.python.tools import optimize_for_inference_lib
from tensorflow.python.saved_model import tag_constants
from model_factory import Factory

# forces tensorflow to run on CPU
os.environ['CUDA_VISIBLE_DEVICES'] = '-1'

parser = argparse.ArgumentParser(description='Freeze your network')

parser.add_argument('--checkpoint', type=str, help='which checkpoint of the network do you want to freeze?', default='./checkpoints/pydnet++')
parser.add_argument('--network',    type=str, help='network to freeze', default='pydnet++')
parser.add_argument('--h',          type=int, default=448, help='height of image')
parser.add_argument('--w',          type=int, default=640, help='width of image')
parser.add_argument('--d',          action='store_true',   help='active debug and visualize graph nodes')
args = parser.parse_args()

def main(_):

    params = {
        'network': args.network,
        'output': 'frozen_models',
        'protobuf' : 'frozen_'+args.network+'.pb',
        'pbtxt': args.network+'.pbtxt',
        'ckpt': args.network+'.ckpt',
        'input_saver_def_path': '',
        'input_binary': False,
        'restore_op' : 'save/restore_all',
        'saving_op': 'save/Const:0',
        'frozen_graph_name': 'frozen_'+args.network+'.pb',
        'optimized_graph_name': 'optimized_'+ args.network+'.pb',
        'optimized_tflite_name': 'tflite_'+ args.network+'.tflite',
        'clear_devices': True,
        'height': args.h,
        'width': args.w,
        'debug': args.d
    }
    
    if not os.path.exists(params['output']):
        os.makedirs(params['output'])

    with tf.Graph().as_default():
        
        model = Factory.get_model(args.network)
        model.build(params)
        params['input_nodes'] = model.input_nodes
        saver = tf.train.Saver()
        with tf.Session() as sess:   
            saver.restore(sess, args.checkpoint)

            if params['debug']:
                for tensor in [n.name for n in tf.get_default_graph().as_graph_def().node]:
                    print(tensor)

            tf.train.write_graph(sess.graph_def, params['output'], params['pbtxt'])  
            graph_pbtxt = os.path.join(params['output'], params['pbtxt'])
            graph_path = os.path.join(params['output'], params['ckpt'])
            saver.save(sess, graph_path)

            outputs = model.output_nodes[0]
            for name in model.output_nodes[1:]:
                outputs +=  ','+name
            
            frozen_graph_path = os.path.join(params['output'], params['frozen_graph_name'])
            freeze_graph.freeze_graph(graph_pbtxt, params['input_saver_def_path'],
                                    params['input_binary'], graph_path, outputs,
                                    params['restore_op'], params['saving_op'],
                                    frozen_graph_path, params['clear_devices'], '')

            converter = tf.lite.TFLiteConverter.from_frozen_graph(frozen_graph_path, params['input_nodes'], model.output_nodes)
            tflite_model = converter.convert()
            optimized_tflite_path = os.path.join(params['output'], params['optimized_tflite_name'])
            open(optimized_tflite_path, "wb").write(tflite_model)

        print('Done!')

if __name__ == '__main__':
    tf.app.run()
