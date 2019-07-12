import tensorflow as tf
from pydnet_pp import PydnetPP

class Factory(object):
    
    @staticmethod
    def get_model(network_name):
        network =  None

        if network_name == 'pydnet++':
            network = PydnetPPModel()
        if network is None:
            raise ValueError('No valid network has been selected')
        return network

class NetworkModel(object):
    def set_inputs(self, params):
        self.input_nodes = [] # this must be a list

    def build(self, params):
        self.set_inputs(params)
        with tf.variable_scope('model'):
            self.model(self.placeholders)

class PydnetPPModel(NetworkModel):
    def __init__(self):
        self.model = PydnetPP
        self.output_nodes = ["PSD/resize/ResizeBilinear","PSD/resize_1/ResizeBilinear","PSD/resize_2/ResizeBilinear"]
    
    def set_inputs(self, params):
        self.placeholders = {'im0':tf.placeholder(tf.float32,[1, params['height'],  params['width'], 3], name='im0')}
        self.input_nodes=['im0']

    def build(self, params):
        self.set_inputs(params)
        with tf.variable_scope('PSD'):
            self.model(self.placeholders['im0'])
