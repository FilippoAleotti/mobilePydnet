package unibo.cvlab.pydnet;

import android.graphics.Color;
import java.util.Arrays;
import java.util.List;

public class ColorMapper {

    private float[] predictions;
    private final float scaleFactor;
    private final boolean applyColorMap;
    private final List<String> colorMap;
    private int[] output;

    public ColorMapper(float scaleFactor, boolean applyColorMap){
        this.scaleFactor = scaleFactor;
        this.applyColorMap = applyColorMap;
        this.colorMap = Utils.getPlasma();
    }


    private class Runner implements Runnable {
        private int start;
        private int end;

        public Runner(int start, int end) {
            this.start = start;
            this.end = end;
        }

        @Override
        public void run() {
            int counter = start;
            for (float prediction : Arrays.copyOfRange(predictions,start,end)) {
                if (applyColorMap) {
                    int colorIndex =  (int)(prediction * scaleFactor);
                    colorIndex = Math.min(Math.max(colorIndex, 0), colorMap.size() - 1);
                    output[counter] = Color.parseColor(colorMap.get(colorIndex));
                } else
                    output[counter] =  (int) (prediction * scaleFactor);
                counter +=1;
            }
        }
    }

    public int[] applyColorMap(float[] inference, int numberThread) {
        // Maybe a threadPool is better, since doing so every time threads are created and destroyed.
        // However, in this way is really easy handling the thread index
        this.predictions = inference;
        this.output = new int[predictions.length];
        int length = Math.round(predictions.length / numberThread);
        Thread[] pool = new Thread[numberThread];

        for (int index = 0; index < numberThread; index++) {
            int current_start = index*length;
            int current_end = current_start + length;
            current_end = Math.min(current_end, predictions.length);
            pool[index] = new Thread(new Runner(current_start, current_end));
            pool[index].start();
        }
        try {
            for (Thread thread : pool)
                thread.join();
            return output;
        }
        catch (InterruptedException e){

            return new int[predictions.length];
        }

    }
}
