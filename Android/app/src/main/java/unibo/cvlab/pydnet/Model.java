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

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.graphics.Bitmap;

import org.tensorflow.lite.Interpreter;

import unibo.cvlab.pydnet.ModelFactory.GeneralModel;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import unibo.cvlab.pydnet.Utils.*;

public abstract class Model{

    protected final String checkpoint;
    protected Map<Scale, String> outputNodes;
    protected List<Resolution> validResolutions;
    protected ModelFactory.GeneralModel generalModel;
    protected String name;
    protected HashMap<String, float[]> results;
    protected HashMap<String, String> inputNodes;

    public Model(Context context, GeneralModel generalModel, String name, String checkpoint){
        this.generalModel = generalModel;
        this.name = name;
        this.outputNodes = new HashMap<>();
        this.inputNodes = new HashMap<>();
        this.checkpoint = checkpoint;
        this.validResolutions = new ArrayList<>();
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

    public abstract void prepare(Utils.Resolution resolution);
    public abstract FloatBuffer doInference(Bitmap input, Utils.Resolution resolution, Utils.Scale scale);
}


