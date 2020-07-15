# PyDNet on mobile devices v2.0
This repository contains the source code to run PyDNet on mobile devices.

# What's new?
In v2.0, we changed the procedure and the data used for training. More information will be provided soon...

Moreover, we build also a web-based demonstration of the same network! You can try it now [here](https://filippoaleotti.github.io/demo_live/).
The model runs directly on your browser, so anything to install! 

<p align="center">
  <img src="assets/live.png" width="500" height="450"/>
</p>

## iOS
The iOS demo has been developed by [Giulio Zaccaroni](https://github.com/GZaccaroni).

XCode is required to build the app, moreover you need to sign in with your AppleID and trust yourself as certified developer.

<p align="center">
<img alt="ios" src="assets/ios.gif">
</p>
<p align="center">
<a href="https://www.youtube.com/watch?v=LRfGablYZNw&feature=youtu.be"><img alt="youtube" src="https://img.youtube.com/vi/LRfGablYZNw/maxresdefault.jpg" class="img-fluid"></a>
</p>

## Android
The code will be released soon

# License
Code is licensed under APACHE version 2.0 license.
Weights of the network can be used for research purposes only.

# Contacts and links
If you use this code in your projects, please cite our paper:

```
@article{aleotti2020real,
  title={Real-time single image depth perception in the wild with handheld devices},
  author={Aleotti, Filippo and Zaccaroni, Giulio and Bartolomei, Luca and Poggi, Matteo and Tosi, Fabio and Mattoccia, Stefano},
  journal={arXiv preprint arXiv:2006.05724},
  year={2020}
}

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
* [Real-time single image depth perception in the wild with handheld devices, Arxiv](https://arxiv.org/pdf/2006.05724.pdf)
* [PyDNet paper](https://arxiv.org/pdf/1806.11430.pdf)
* [PyDNet code](https://github.com/mattpoggi/pydnet)

For questions, please send an email to filippo.aleotti2@unibo.it
