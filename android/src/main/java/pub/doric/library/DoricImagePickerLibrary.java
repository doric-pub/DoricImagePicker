package pub.doric.library;

import java.io.IOException;
import java.io.InputStream;

import pub.doric.Doric;
import pub.doric.DoricComponent;
import pub.doric.DoricLibrary;
import pub.doric.DoricRegistry;

@DoricComponent
public class DoricImagePickerLibrary extends DoricLibrary {
    @Override
    public void load(DoricRegistry registry) {
        try {
            InputStream is = Doric.application().getAssets().open("bundle_doricimagepicker.js");
            byte[] bytes = new byte[is.available()];
            is.read(bytes);
            String content = new String(bytes);
            registry.registerJSBundle("doric-imagepicker", content);
        } catch (IOException e) {
            e.printStackTrace();
        }
        registry.registerNativePlugin(DoricImagePickerPlugin.class);
    }
}
