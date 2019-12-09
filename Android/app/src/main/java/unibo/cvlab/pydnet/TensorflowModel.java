package unibo.cvlab.pydnet;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;

import org.tensorflow.contrib.android.TensorFlowInferenceInterface;

import java.nio.ByteBuffer;
import java.nio.FloatBuffer;

public class TensorflowModel extends Model{
    protected TensorFlowInferenceInterface inferenceEngine;
    private float[] floatPixelBuffer;
    private int[] intPixelBuffer;
    private float[] outputBytes;
    private boolean isPrepared = false;

    public TensorflowModel(Context context, ModelFactory.GeneralModel generalModel, String name, String checkpoint){
        super(context, generalModel, name, checkpoint);
        this.inferenceEngine = new TensorFlowInferenceInterface(context.getAssets(),
                "file:///android_asset/" + checkpoint);

    }

    @Override
    public void prepare(Utils.Resolution resolution) {

        intPixelBuffer = new int[resolution.getWidth() * resolution.getHeight()];
        floatPixelBuffer = new float[resolution.getWidth() * resolution.getHeight() * 3];
        outputBytes = new float[resolution.getHeight()*resolution.getWidth()];
        isPrepared = true;
    }

    public FloatBuffer doInference(Bitmap input, Utils.Resolution resolution, Utils.Scale scale){
        if (!isPrepared) {
            throw new RuntimeException("Model is not prepared.");
        }

        fillFloatPixelBufferFromBitmap(input);

        this.inferenceEngine.feed(
                getInputNode("image") + ":0", floatPixelBuffer, 1,
                resolution.getHeight(), resolution.getWidth(), 3);
        this.inferenceEngine.run(new String[]{this.outputNodes.get(scale)+":0"});
        this.inferenceEngine.fetch(outputNodes.get(scale) + ":0", outputBytes);
        return FloatBuffer.wrap(outputBytes);
    }

    private void fillFloatPixelBufferFromBitmap(Bitmap frame) {

        frame.getPixels(intPixelBuffer, 0, frame.getWidth(), 0, 0, frame.getWidth(), frame.getHeight());

        int i = 0;
        for (int pixel : intPixelBuffer) {
            floatPixelBuffer[i * 3] = Color.red(pixel) / (float) 255.;
            floatPixelBuffer[i * 3 + 1] = Color.green(pixel) / (float) 255.;
            floatPixelBuffer[i * 3 + 2] = Color.blue(pixel) / (float) 255.;
            i += 1;
        }
    }
}
