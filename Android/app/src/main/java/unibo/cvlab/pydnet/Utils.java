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

import android.graphics.Bitmap;
import android.graphics.Color;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class Utils {

    public enum Scale {
        FULL(1.f), HALF(0.5f), QUARTER(0.25f), HEIGHT(0.125f);

        private float value;

        Scale(float value){
            this.value = value;
        }

        public float getValue(){
            return this.value;
        }

        public String toString(){
            switch(this){
                case FULL:
                    return "Full";
                case HALF:
                    return "Half";
                case QUARTER:
                    return "Quarter";
                case HEIGHT:
                    return "Height";
            }
            return "Not valid resolution";
        }
    }

    public enum Resolution{
        RES1(512,256), RES2(640,192), RES3(320,96), RES4(640,448);

        private final int width;
        private final int height;

        Resolution(int width, int height) {
            this.width = width;
            this.height = height;
        }

        public String toString(){
            return ""+this.width+"x"+this.height;
        }

        public int getWidth(){
            return this.width;
        }

        public int getHeight(){
            return this.height;
        }
    }

    public static List<String> getPlasma(){
        // A better approach would be read the colormap from assets...
        List<String> color = new ArrayList<>();
        color.add("#F0F921");
        color.add("#F0F724");
        color.add("#F1F525");
        color.add("#F1F426");
        color.add("#F2F227");
        color.add("#F3F027");
        color.add("#F3EE27");
        color.add("#F4ED27");
        color.add("#F5EB27");
        color.add("#F5E926");
        color.add("#F6E826");
        color.add("#F6E626");
        color.add("#F7E425");
        color.add("#F7E225");
        color.add("#F8E125");
        color.add("#F8DF25");
        color.add("#F9DD25");
        color.add("#F9DC24");
        color.add("#FADA24");
        color.add("#FAD824");
        color.add("#FBD724");
        color.add("#FBD524");
        color.add("#FBD324");
        color.add("#FCD225");
        color.add("#FCD025");
        color.add("#FCCE25");
        color.add("#FCCD25");
        color.add("#FDCB26");
        color.add("#FDCA26");
        color.add("#FDC827");
        color.add("#FDC627");
        color.add("#FDC527");
        color.add("#FDC328");
        color.add("#FDC229");
        color.add("#FEC029");
        color.add("#FEBE2A");
        color.add("#FEBD2A");
        color.add("#FEBB2B");
        color.add("#FEBA2C");
        color.add("#FEB82C");
        color.add("#FEB72D");
        color.add("#FDB52E");
        color.add("#FDB42F");
        color.add("#FDB22F");
        color.add("#FDB130");
        color.add("#FDAF31");
        color.add("#FDAE32");
        color.add("#FDAC33");
        color.add("#FDAB33");
        color.add("#FCA934");
        color.add("#FCA835");
        color.add("#FCA636");
        color.add("#FCA537");
        color.add("#FCA338");
        color.add("#FBA238");
        color.add("#FBA139");
        color.add("#FB9F3A");
        color.add("#FA9E3B");
        color.add("#FA9C3C");
        color.add("#FA9B3D");
        color.add("#F99A3E");
        color.add("#F9983E");
        color.add("#F9973F");
        color.add("#F89540");
        color.add("#F89441");
        color.add("#F79342");
        color.add("#F79143");
        color.add("#F79044");
        color.add("#F68F44");
        color.add("#F68D45");
        color.add("#F58C46");
        color.add("#F58B47");
        color.add("#F48948");
        color.add("#F48849");
        color.add("#F3874A");
        color.add("#F3854B");
        color.add("#F2844B");
        color.add("#F1834C");
        color.add("#F1814D");
        color.add("#F0804E");
        color.add("#F07F4F");
        color.add("#EF7E50");
        color.add("#EF7C51");
        color.add("#EE7B51");
        color.add("#ED7A52");
        color.add("#ED7953");
        color.add("#EC7754");
        color.add("#EB7655");
        color.add("#EB7556");
        color.add("#EA7457");
        color.add("#E97257");
        color.add("#E97158");
        color.add("#E87059");
        color.add("#E76F5A");
        color.add("#E76E5B");
        color.add("#E66C5C");
        color.add("#E56B5D");
        color.add("#E56A5D");
        color.add("#E4695E");
        color.add("#E3685F");
        color.add("#E26660");
        color.add("#E26561");
        color.add("#E16462");
        color.add("#E06363");
        color.add("#DF6263");
        color.add("#DE6164");
        color.add("#DE5F65");
        color.add("#DD5E66");
        color.add("#DC5D67");
        color.add("#DB5C68");
        color.add("#DA5B69");
        color.add("#DA5A6A");
        color.add("#D9586A");
        color.add("#D8576B");
        color.add("#D7566C");
        color.add("#D6556D");
        color.add("#D5546E");
        color.add("#D5536F");
        color.add("#D45270");
        color.add("#D35171");
        color.add("#D24F71");
        color.add("#D14E72");
        color.add("#D04D73");
        color.add("#CF4C74");
        color.add("#CE4B75");
        color.add("#CD4A76");
        color.add("#CC4977");
        color.add("#CC4778");
        color.add("#CB4679");
        color.add("#CA457A");
        color.add("#C9447A");
        color.add("#C8437B");
        color.add("#C7427C");
        color.add("#C6417D");
        color.add("#C5407E");
        color.add("#C43E7F");
        color.add("#C33D80");
        color.add("#C23C81");
        color.add("#C13B82");
        color.add("#C03A83");
        color.add("#BF3984");
        color.add("#BE3885");
        color.add("#BD3786");
        color.add("#BC3587");
        color.add("#BB3488");
        color.add("#BA3388");
        color.add("#B83289");
        color.add("#B7318A");
        color.add("#B6308B");
        color.add("#B52F8C");
        color.add("#B42E8D");
        color.add("#B32C8E");
        color.add("#B22B8F");
        color.add("#B12A90");
        color.add("#B02991");
        color.add("#AE2892");
        color.add("#AD2793");
        color.add("#AC2694");
        color.add("#AB2494");
        color.add("#AA2395");
        color.add("#A82296");
        color.add("#A72197");
        color.add("#A62098");
        color.add("#A51F99");
        color.add("#A31E9A");
        color.add("#A21D9A");
        color.add("#A11B9B");
        color.add("#A01A9C");
        color.add("#9E199D");
        color.add("#9D189D");
        color.add("#9C179E");
        color.add("#9A169F");
        color.add("#99159F");
        color.add("#9814A0");
        color.add("#9613A1");
        color.add("#9511A1");
        color.add("#9410A2");
        color.add("#920FA3");
        color.add("#910EA3");
        color.add("#8F0DA4");
        color.add("#8E0CA4");
        color.add("#8D0BA5");
        color.add("#8B0AA5");
        color.add("#8A09A5");
        color.add("#8808A6");
        color.add("#8707A6");
        color.add("#8606A6");
        color.add("#8405A7");
        color.add("#8305A7");
        color.add("#8104A7");
        color.add("#8004A8");
        color.add("#7E03A8");
        color.add("#7D03A8");
        color.add("#7B02A8");
        color.add("#7A02A8");
        color.add("#7801A8");
        color.add("#7701A8");
        color.add("#7501A8");
        color.add("#7401A8");
        color.add("#7201A8");
        color.add("#7100A8");
        color.add("#6F00A8");
        color.add("#6E00A8");
        color.add("#6C00A8");
        color.add("#6A00A8");
        color.add("#6900A8");
        color.add("#6700A8");
        color.add("#6600A7");
        color.add("#6400A7");
        color.add("#6300A7");
        color.add("#6100A7");
        color.add("#6001A6");
        color.add("#5E01A6");
        color.add("#5C01A6");
        color.add("#5B01A5");
        color.add("#5901A5");
        color.add("#5801A4");
        color.add("#5601A4");
        color.add("#5502A4");
        color.add("#5302A3");
        color.add("#5102A3");
        color.add("#5002A2");
        color.add("#4E02A2");
        color.add("#4C02A1");
        color.add("#4B03A1");
        color.add("#4903A0");
        color.add("#48039F");
        color.add("#46039F");
        color.add("#44039E");
        color.add("#43039E");
        color.add("#41049D");
        color.add("#3F049C");
        color.add("#3E049C");
        color.add("#3C049B");
        color.add("#3A049A");
        color.add("#38049A");
        color.add("#370499");
        color.add("#350498");
        color.add("#330597");
        color.add("#310597");
        color.add("#2F0596");
        color.add("#2E0595");
        color.add("#2C0594");
        color.add("#2A0593");
        color.add("#280592");
        color.add("#260591");
        color.add("#240691");
        color.add("#220690");
        color.add("#20068F");
        color.add("#1D068E");
        color.add("#1B068D");
        color.add("#19068C");
        color.add("#16078A");
        color.add("#130789");
        color.add("#100788");
        color.add("#0D0887");

        return color;
    }

    public static float[] getPixelFromBitmap(Bitmap frame){
        int numberOfPixels = frame.getWidth()*frame.getHeight()*3;
        int[] pixels = new int[frame.getWidth()*frame.getHeight()];
        frame.getPixels(pixels, 0, frame.getWidth(), 0, 0, frame.getWidth(), frame.getHeight());

        float[] output = new float[numberOfPixels];

        int i = 0;
        for (int pixel : pixels) {
            output[i * 3] = Color.red(pixel) /(float)255.;
            output[i * 3 + 1] = Color.green(pixel) / (float)255.;
            output[i * 3+2] = Color.blue(pixel) / (float)255.;
            i+=1;
        }
        return output;
    }
}
