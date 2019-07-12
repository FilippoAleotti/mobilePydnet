package unibo.cvlab.pydnet;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.widget.Toast;

import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.gpu.GpuDelegate;
import unibo.cvlab.pydnet.ModelFactory.GeneralModel;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import unibo.cvlab.pydnet.Utils.*;

public class Model{

    protected final String checkpoint;
    protected Map<Scale, String> outputNodes;
    protected List<Resolution> validResolutions;
    protected ModelFactory.GeneralModel generalModel;
    protected String name;
    protected Interpreter inferenceEngine;
    protected HashMap<String, float[]> results;
    protected HashMap<String, String> inputNodes;

    // From tensorflow examples
    // https://github.com/tensorflow/examples/blob/master/lite/examples/image_classification/android/app/src/main/java/org/tensorflow/lite/examples/classification/tflite/Classifier.java
    private MappedByteBuffer loadModelFile(Context context, String checkpoint) throws IOException {

        final String[] names = context.getAssets().list("" );
        AssetFileDescriptor fileDescriptor = context.getAssets().openFd(checkpoint);
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        long startOffset = fileDescriptor.getStartOffset();
        long declaredLength = fileDescriptor.getDeclaredLength();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
    }

    public Model(Context context, GeneralModel generalModel, String name, String checkpoint){
        this.generalModel = generalModel;
        this.name = name;
        this.outputNodes = new HashMap<>();
        this.inputNodes = new HashMap<>();
        this.checkpoint = checkpoint;

        // adding GPU visibility
        GpuDelegate delegate = new GpuDelegate();
        Interpreter.Options options = (new Interpreter.Options()).addDelegate(delegate);
        options.setNumThreads(Runtime.getRuntime().availableProcessors());
        try {
            this.inferenceEngine = new Interpreter(loadModelFile(context, checkpoint), options);
        }
        catch (IOException ex){
            Toast.makeText(context,ex.getMessage(), Toast.LENGTH_LONG).show();
        }

        validResolutions = new ArrayList<>();
        this.results = new HashMap<>();

    }


    public void addOutputNodes(Scale scale, String node){
            this.outputNodes.put(scale,node);
    }

    public void addInputNode(String name, String node){
        if(!this.inputNodes.containsKey(name))
            this.inputNodes.put(name, node);
    }

    public void addValidResolution(Resolution resolution){
        if(!this.validResolutions.contains(resolution))
            this.validResolutions.add(resolution);
    }

    public String getInputNode(String name){
        return this.inputNodes.get(name);
    }

    public float[] doInference(float[] input, Resolution resolution, Scale scale){
        float[][] output = new float[resolution.getHeight()][resolution.getWidth()];

        this.inferenceEngine.run(input, output);
        int length = resolution.getHeight()* resolution.getWidth();
        float[] output_reshaped = new float[length];

        for(int row_index=0; row_index < resolution.getHeight(); row_index++){
            for(int col_index=0; col_index < resolution.getWidth(); col_index++){
                output_reshaped[row_index*resolution.getHeight()+col_index] = output[row_index][col_index];
            }
        }
        return output_reshaped;
    }
}


