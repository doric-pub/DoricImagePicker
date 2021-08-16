import { BridgeContext } from "doric";

export enum ImageSource {
  Gallery = 0,
  Camera = 1,
}

export interface ImageFile {
  filePath: string;
}

export function imagePicker(context: BridgeContext) {
  return {
    pickImage: (params: {
      source: ImageSource;
      cameraDevice?: "front" | "back";
      maxWidth?: number;
      maxHeight?: number;
      imageQuality?: number;
    }) => {
      return context.callNative("imagePicker", "pickImage", params) as Promise<
        ImageFile | undefined
      >;
    },
    pickVideo: (params: {
      source: ImageSource;
      cameraDevice?: "front" | "back";
      maxDuration?: number;
    }) => {
      return context.callNative("imagePicker", "pickVideo", params) as Promise<
        ImageFile | undefined
      >;
    },
    pickMultiImage: (params: {
      maxWidth?: number;
      maxHeight?: number;
      imageQuality?: number;
    }) => {
      return context.callNative(
        "imagePicker",
        "pickMultiImage",
        params
      ) as Promise<ImageFile[] | undefined>;
    },
  };
}
