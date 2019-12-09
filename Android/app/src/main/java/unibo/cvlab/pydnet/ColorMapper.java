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

* Author: Filippo Aleotti
* Mail: filippo.aleotti2@unibo.it
*/

package unibo.cvlab.pydnet;

import android.graphics.Color;
import android.util.Log;

import java.nio.FloatBuffer;
import java.util.Arrays;
import java.util.List;

public class ColorMapper {

    private FloatBuffer predictions;
    private final float scaleFactor;
    private final boolean applyColorMap;
    private final List<String> colorMap;
    private int[] output;
    private boolean isPrepared = false;

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
            for(int i = start; i < end; i++){
                float prediction = predictions.get(i);
                if (applyColorMap) {
                    int colorIndex =  (int)(prediction * scaleFactor);
                    colorIndex = Math.min(Math.max(colorIndex, 0), colorMap.size() - 1);
                    output[i] = Color.parseColor(colorMap.get(colorIndex));
                } else
                    output[i] =  (int) (prediction * scaleFactor);
            }
        }
    }

    public void prepare(Utils.Resolution resolution){
        this.output = new int[resolution.getHeight()*resolution.getWidth()*4];
        isPrepared = true;
    }
    public int[] applyColorMap(FloatBuffer inference, int numberThread) {
        if (!isPrepared) {
            throw new RuntimeException("ColorMapper is not prepared.");
        }

        // Maybe a threadPool is better, since doing so every time threads are created and destroyed.
        // However, in this way is really easy handling the thread index
        inference.rewind();
        this.predictions = inference;
        int inferenceLength = inference.remaining();

        int length = Math.round(inferenceLength / numberThread);
        Thread[] pool = new Thread[numberThread];

        for (int index = 0; index < numberThread; index++) {
            int current_start = index*length;
            int current_end = current_start + length;
            current_end = Math.min(current_end, inferenceLength);
            pool[index] = new Thread(new Runner(current_start, current_end));
            pool[index].start();
        }
        try {
            for (Thread thread : pool)
                thread.join();
            return output;
        }
        catch (InterruptedException e){

            return new int[inferenceLength];
        }

    }
}
