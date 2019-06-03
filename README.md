# PyDNet on mobile devices

This repository contains the source code to run PyDNet on mobile devices (`Android` and `iOS`)


If you use this code in your projects, please cite our paper:

```
@inproceedings{pydnet18,
  title     = {Towards real-time unsupervised monocular depth estimation on CPU},
  author    = {Poggi, Matteo and
               Aleotti, Filippo and
               Tosi, Fabio and
               Mattoccia, Stefano},
  booktitle = {IEEE/JRS Conference on Intelligent Robots and Systems (IROS)},
  year = {2018}
}
```

More info about the work can be found at these links:
* [PyDNet paper](https://arxiv.org/pdf/1806.11430.pdf)
* [PyDNet code](https://github.com/mattpoggi/pydnet)

## Model
The network has been trained on [MatterPort](https://matterport.com/it/) dataset for 1.2M steps, using the HuBer loss on disparity labels offered by the dataset as supervision.

## Android
The code is based on [Google android examples](https://github.com/tensorflow/tensorflow/tree/master/tensorflow/examples/android).

Android `target` version is 26 while `minimum` is 21. 

## iOS
The demo on iOS has been developed by Giulio Zaccaroni

## License

The code provided in this repository has a demonstrative purpose only. You can download, modify and try it on your mobile phone with no restriction. However, the trained model can not be used for any scopes not covered by [MatterPort](https://matterport.com/it/) license.