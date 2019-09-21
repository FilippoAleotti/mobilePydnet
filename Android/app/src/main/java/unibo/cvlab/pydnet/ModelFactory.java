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
import unibo.cvlab.pydnet.Utils.*;
import java.util.ArrayList;
import java.util.List;

public class ModelFactory {

    private final Context context;

    private List<Model> models;

    public enum GeneralModel{
        PYDNET_PP
    }

    public ModelFactory(Context context){
       this.context = context;
       this.models = new ArrayList<>();
       models.add(createPydnetPP());
    }

    public Model getModel(int index ){
        return models.get(index);
    }

    private Model createPydnetPP(){
        Model pydnetPP;
        pydnetPP = new Model(context, GeneralModel.PYDNET_PP, "Pydnet++", "file:///android_asset/optimized_pydnet++.pb");
        pydnetPP.addInputNode("image", "im0:0");
        pydnetPP.addOutputNodes(Scale.HALF, "PSD/resize_images/ResizeBilinear:0");
        pydnetPP.addOutputNodes(Scale.QUARTER, "PSD/resize_images_1/ResizeBilinear:0");
        pydnetPP.addOutputNodes(Scale.HEIGHT, "PSD/resize_images_2/ResizeBilinear:0");
        pydnetPP.addValidResolution(Resolution.RES4);
        return pydnetPP;
    }

}


