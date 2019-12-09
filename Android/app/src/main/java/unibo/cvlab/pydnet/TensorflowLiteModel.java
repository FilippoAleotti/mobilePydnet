package unibo.cvlab.pydnet;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.support.annotation.NonNull;

import org.tensorflow.lite.Interpreter;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.HashMap;
import java.util.Map;

public class TensorflowLiteModel extends Model{
    protected Interpreter tfLite;
    private ByteBuffer outputByteBuffer;
    private ByteBuffer inputByteBuffer;
    private int[] intInputPixels;
    private boolean isPrepared = false;

    public TensorflowLiteModel(Context context, ModelFactory.GeneralModel generalModel, String name, String checkpoint){
        super(context, generalModel, name, checkpoint);

        Interpreter.Options tfliteOptions = new Interpreter.Options();

        try {
            this.tfLite = new Interpreter(loadModelFile(context.getAssets(), checkpoint), tfliteOptions);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void prepare(Utils.Resolution resolution) {
        outputByteBuffer = ByteBuffer.allocateDirect(resolution.getHeight() * resolution.getWidth() * 4);
        inputByteBuffer = ByteBuffer.allocateDirect(3 * resolution.getHeight() * resolution.getWidth() * 4);
        intInputPixels = new int[resolution.getWidth() * resolution.getHeight()];
        inputByteBuffer.order(ByteOrder.nativeOrder());
        outputByteBuffer.order(ByteOrder.nativeOrder());
        isPrepared = true;

    }

    @NonNull
    public FloatBuffer doInference(Bitmap input, Utils.Resolution resolution, Utils.Scale scale){
        if (!isPrepared) {
            throw new RuntimeException("Model is not prepared.");
        }
        inputByteBuffer.rewind();
        outputByteBuffer.rewind();

        fillInputByteBufferWithBitmap(input);
        inputByteBuffer.rewind();
        Object[] inputArray = new Object[tfLite.getInputTensorCount()];
        inputArray[tfLite.getInputIndex(getInputNode("image"))] = inputByteBuffer;

        Map<Integer, Object> outputMap = new HashMap<>();
        outputMap.put(tfLite.getOutputIndex(outputNodes.get(scale)), outputByteBuffer);

        this.tfLite.runForMultipleInputsOutputs(inputArray, outputMap);

        outputByteBuffer.rewind();
        return outputByteBuffer.asFloatBuffer();
    }

    // Helper methods

    private void fillInputByteBufferWithBitmap(Bitmap bitmap) {
        bitmap.getPixels(intInputPixels, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        // Convert the image to floating point.
        int pixel = 0;
        for (int i = 0; i < bitmap.getWidth(); ++i) {
            for (int j = 0; j < bitmap.getHeight(); ++j) {
                final int val = intInputPixels[pixel++];
                inputByteBuffer.putFloat((((val >> 16) & 0xFF))/(float) 255.);
                inputByteBuffer.putFloat((((val >> 8) & 0xFF))/(float) 255.);
                inputByteBuffer.putFloat((((val) & 0xFF))/(float) 255.);
            }
        }
    }

    // Helper static methods

    private static MappedByteBuffer loadModelFile(AssetManager assets, String modelFilename)
            throws IOException {
        AssetFileDescriptor fileDescriptor = assets.openFd(modelFilename);
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        long startOffset = fileDescriptor.getStartOffset();
        long declaredLength = fileDescriptor.getDeclaredLength();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
    }
}
