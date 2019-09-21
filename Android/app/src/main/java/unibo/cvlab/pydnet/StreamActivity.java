/**
/*
Copyright 2019 Filippo Aleotti

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

 * Video stream, with depth map acquisition.
 * Code is partially based on Android Tensorflow examples, with APACHE license
 * https://github.com/tensorflow/tensorflow/blob/master/tensorflow/examples/android/src/org/tensorflow/demo/ClassifierActivity.java
 *
 * Author: Filippo Aleotti
 * Mail: filippo.aleotti2@unibo.it
 */
 
package unibo.cvlab.pydnet;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Canvas;
import android.graphics.Point;
import android.graphics.Rect;
import android.os.Bundle;
import android.graphics.Matrix;
import android.util.Size;
import android.media.ImageReader.OnImageAvailableListener;
import android.view.Display;
import android.view.View;
import unibo.cvlab.pydnet.demo.AutoFitTextureView;
import unibo.cvlab.pydnet.demo.CameraActivity;
import unibo.cvlab.pydnet.demo.ImageUtils;
import unibo.cvlab.pydnet.demo.OverlayView;

public class StreamActivity extends CameraActivity implements OnImageAvailableListener{
    private ModelFactory modelFactory;
    private Model currentModel;
    private Integer sensorOrientation;
    private Matrix frameToCropTransform;
    private Size halfScreenSize = null;
    private Size screenSize = null;
    private Utils.Resolution resolution = Utils.Resolution.RES4;
    private Bitmap originalFrame = null;
    private Bitmap croppedFrame = null;
    private Bitmap outputDisp = null;
    private Bitmap outputDispResized = null;
    private Bitmap outputRGB = null;
    private ColorMapper colorMapper = null;
    private boolean applyColormap = true;
    private static final boolean MAINTAIN_ASPECT = true;
    private Utils.Scale scale = Utils.Scale.HALF;
    private static float COLOR_SCALE_FACTOR =  10.5f;
    private static int NUMBER_THREADS = Runtime.getRuntime().availableProcessors();

    @Override
    public void onPreviewSizeChosen(final Size size, final int rotation) {
        previewWidth = size.getWidth();
        previewHeight = size.getHeight();
        Display display = getWindowManager().getDefaultDisplay();
        Point pointScreen = new Point();
        display.getSize(pointScreen);
        halfScreenSize = new Size(pointScreen.x, pointScreen.y/2);
        sensorOrientation = rotation - getScreenOrientation();
        originalFrame = Bitmap.createBitmap(previewWidth, previewHeight, Config.ARGB_8888);
        croppedFrame = Bitmap.createBitmap(resolution.getWidth(), resolution.getHeight(), Config.ARGB_8888);
        outputDisp = Bitmap.createBitmap(resolution.getWidth(), resolution.getHeight(), Config.ARGB_8888);
        outputDispResized = Bitmap.createBitmap(halfScreenSize.getWidth(), halfScreenSize.getHeight(), Config.ARGB_8888);
        outputRGB = Bitmap.createBitmap(halfScreenSize.getWidth(), halfScreenSize.getHeight(), Config.ARGB_8888);

        frameToCropTransform = ImageUtils.getTransformationMatrix(
                previewWidth, previewHeight,
                resolution.getWidth(), resolution.getHeight(),
                sensorOrientation, MAINTAIN_ASPECT);

        addCallback(
            new OverlayView.DrawCallback() {
                @Override
                public void drawCallback(final Canvas canvas) {
                    renderDepthMap(canvas);
                }
            });
        AutoFitTextureView cameraPreview = findViewById(R.id.image);
        cameraPreview.setVisibility(View.INVISIBLE);
    }

    private void renderDepthMap(Canvas canvas){
        if (outputDispResized != null) {
            canvas.drawBitmap(outputRGB, null, new Rect(0,0,
                   halfScreenSize.getWidth(), halfScreenSize.getHeight()), null);
            canvas.drawBitmap(outputDispResized, 0, halfScreenSize.getHeight(), null);
        }
    }

    // From https://github.com/tensorflow/tensorflow/blob/master/tensorflow/examples/android/src/org/tensorflow/demo/ClassifierActivity.java
    @Override
    protected int getLayoutId() {
        return R.layout.camera_connection_fragment;
    }

    // From https://github.com/tensorflow/tensorflow/blob/master/tensorflow/examples/android/src/org/tensorflow/demo/ClassifierActivity.java
    @Override
    protected Size getDesiredPreviewFrameSize() {
        if (screenSize == null){
            Display display = getWindowManager().getDefaultDisplay();
            Point screenSizeHandler = new Point();
            display.getSize(screenSizeHandler);
            screenSize = new Size(screenSizeHandler.x, screenSizeHandler.y);
        }
        return screenSize;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_stream);
        modelFactory = new ModelFactory(getApplicationContext());
        currentModel = modelFactory.getModel(0);
        colorMapper = new ColorMapper(COLOR_SCALE_FACTOR ,applyColormap);
    }

    @Override
    protected void processImage() {
        originalFrame.setPixels(getRgbBytes(), 0, previewWidth, 0, 0, previewWidth, previewHeight);
        final Canvas canvas = new Canvas(croppedFrame);
        canvas.drawBitmap(originalFrame, frameToCropTransform, null);
        runInBackground(
            new Runnable() {
                @Override
                public void run() {
                    float[] pixels = Utils.getPixelFromBitmap(croppedFrame);
                    doInference(pixels);
                    requestRender();
                    readyForNextImage();
                }
            });
    }

    private void doInference(float[] input){
        float[] inference;
        inference = currentModel.doInference(input, resolution, scale);
        int[] coloredInference = colorMapper.applyColorMap(inference, NUMBER_THREADS);
        outputDisp.setPixels(coloredInference, 0, resolution.getWidth(), 0, 0, resolution.getWidth(), resolution.getHeight());
        outputDispResized = Bitmap.createScaledBitmap(outputDisp,  halfScreenSize.getWidth(), halfScreenSize.getHeight(), false);
        outputRGB = Bitmap.createScaledBitmap(croppedFrame,  halfScreenSize.getWidth(), halfScreenSize.getHeight(), false);
    }
}
