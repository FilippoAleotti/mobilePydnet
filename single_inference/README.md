# Single inference
Single inference using TensorFlow 1.15 and python 3.x.
You can install requirements by running the script:

```
python install -r requirements.txt
```

# Train files
The file `train_files.txt` contains the images used to train the network.
In particular:
* `Coco`: http://images.cocodataset.org/zips/unlabeled2017.zip
* `OpenImages`: https://github.com/cvdfoundation/open-images-dataset#download-images-with-bounding-boxes-annotations

# Run

1. Download pretrained TensorFlow model [here](https://drive.google.com/file/d/1Zu41tHv89q_F7N5KFigzyUY5vAc8ufQL/view?usp=sharing), and move it into `ckpt` folder.
2. run the `run.sh` script.

# License
Code is licensed under Apache v2.0
Pre-trained models can be used only for research purposes.
Images inside `test` folder are from [Pexels](https://www.pexels.com/)