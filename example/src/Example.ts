import {
  Panel,
  Group,
  vlayout,
  layoutConfig,
  Gravity,
  text,
  Color,
  navbar,
  modal,
  image,
  Image,
} from "doric";
import { imagePicker, ImageSource } from "doric-imagepicker";

@Entry
class Example extends Panel {
  onShow() {
    navbar(context).setTitle("Example");
  }
  build(rootView: Group) {
    let previewView: Image;
    vlayout([
      text({
        text: "Pick image",
        textSize: 20,
        backgroundColor: Color.parse("#70a1ff"),
        textColor: Color.WHITE,
        onClick: async () => {
          const result = await imagePicker(this.context).pickImage({
            source: ImageSource.Gallery,
          });
          if (result) {
            await modal(this.context).alert(JSON.stringify(result));
          } else {
            await modal(this.context).alert("User canceled.");
          }
        },
        layoutConfig: layoutConfig().fit(),
        padding: { left: 20, right: 20, top: 20, bottom: 20 },
      }),
      text({
        text: "Pick video",
        textSize: 20,
        backgroundColor: Color.parse("#70a1ff"),
        textColor: Color.WHITE,
        onClick: async () => {
          const result = await imagePicker(this.context).pickVideo({
            source: ImageSource.Gallery,
          });
          if (result) {
            await modal(this.context).alert(JSON.stringify(result));
          } else {
            await modal(this.context).alert("User canceled.");
          }
        },
        layoutConfig: layoutConfig().fit(),
        padding: { left: 20, right: 20, top: 20, bottom: 20 },
      }),
      text({
        text: "Pick multi image",
        textSize: 20,
        backgroundColor: Color.parse("#70a1ff"),
        textColor: Color.WHITE,
        onClick: async () => {
          const result = await imagePicker(this.context).pickMultiImage({
            source: ImageSource.Gallery,
          });
          if (result) {
            await modal(this.context).alert(JSON.stringify(result));
          } else {
            await modal(this.context).alert("User canceled.");
          }
        },
        layoutConfig: layoutConfig().fit(),
        padding: { left: 20, right: 20, top: 20, bottom: 20 },
      }),
      text({
        text: "Pick multi video",
        textSize: 20,
        backgroundColor: Color.parse("#70a1ff"),
        textColor: Color.WHITE,
        onClick: async () => {
          const result = await imagePicker(this.context).pickMultiVideo({
            source: ImageSource.Gallery,
          });
          if (result) {
            await modal(this.context).alert(JSON.stringify(result));
          } else {
            await modal(this.context).alert("User canceled.");
          }
        },
        layoutConfig: layoutConfig().fit(),
        padding: { left: 20, right: 20, top: 20, bottom: 20 },
      }),
      (previewView = image({
        layoutConfig: layoutConfig().just(),
        width: 100,
        height: 100,
      })),
    ])
      .apply({
        layoutConfig: layoutConfig().fit().configAlignment(Gravity.Center),
        space: 20,
        gravity: Gravity.Center,
      })
      .in(rootView);
  }
}
