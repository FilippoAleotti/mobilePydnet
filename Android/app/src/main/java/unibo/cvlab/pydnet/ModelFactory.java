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


